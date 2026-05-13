const { ApolloServer, gql } = require('apollo-server');
const { PubSub } = require('graphql-subscriptions');
const DataLoader = require('dataloader');
const axios = require('axios');

const REST_API = process.env.REST_API_URL || 'http://surypus-api:8080/api/v1';
const pubsub = new PubSub();

// DataLoader instances to prevent N+1 query problems
const createDataLoaders = () => ({
  personLoader: new DataLoader(async (ids) => {
    const persons = await axios.get(`${REST_API}/persons`, {
      params: { ids: ids.join(',') }
    });
    // Map results to match ID order
    const personMap = {};
    persons.data.forEach(person => {
      personMap[person.id] = person;
    });
    return ids.map(id => personMap[id]);
  }),
  
  goodsLoader: new DataLoader(async (ids) => {
    const goods = await axios.get(`${REST_API}/goods`, {
      params: { ids: ids.join(',') }
    });
    // Map results to match ID order
    const goodsMap = {};
    goods.data.forEach(good => {
      goodsMap[good.id] = good;
    });
    return ids.map(id => goodsMap[id]);
  }),
  
  locationLoader: new DataLoader(async (ids) => {
    const locations = await axios.get(`${REST_API}/locations`, {
      params: { ids: ids.join(',') }
    });
    // Map results to match ID order
    const locationMap = {};
    locations.data.forEach(location => {
      locationMap[location.id] = location;
    });
    return ids.map(id => locationMap[id]);
  })
});

// Simple in-memory caches
let dashboardCache = { data: null, expiresAt: 0 };
let billsCache = { data: null, expiresAt: 0 };
let paymentsCache = { data: null, expiresAt: 0 };
let personsCache = { data: null, expiresAt: 0 };
let goodsCache = { data: null, expiresAt: 0 };
let balanceCache = {};

// GraphQL Schema with Person, Goods, Location, Stock types
const typeDefs = gql`
  type BillLine { id: ID!, goodId: ID!, quantity: Int!, price: Float!, amount: Float! }
  type Bill { id: ID!, number: String!, date: String, currency: String, total_amount: Float, status: String!, lines: [BillLine!]! }
  type Payment { id: ID!, billId: ID!, amount: Float!, status: String!, createdAt: String }
  type Dashboard { revenue: Float, stockValue: Float, pendingPayments: Int }
  type Balance { accountId: ID!, balance: Float! }
  
  # Person types
  type Person { id: ID!, name: String!, inn: String, kpp: String, type: Int, status: Int }
  input PersonInput { name: String!, inn: String, kpp: String, type: Int, status: Int }
  
  # Goods types
  type Goods { id: ID!, name: String!, article: String, unit: String }
  input GoodsInput { name: String!, article: String, unit: String }
  
  # Location types
  type Location { id: ID!, name: String!, code: String }
  input LocationInput { name: String!, code: String }
  
   # Stock types
   type Stock { goodsId: ID!, locationId: ID!, quantity: Float!, reserved: Float! }
   input StockInput { goodsId: ID!, locationId: ID!, quantity: Float!, reserved: Float! }
   
   type Query { 
     bills(limit: Int, offset: Int): [Bill!]!, 
     bill(id: ID!): Bill, 
     payments(limit: Int, offset: Int): [Payment!]!, 
     payment(id: ID!): Payment, 
     dashboard: Dashboard, 
     balance(accountId: ID!): Balance,
     persons(limit: Int, offset: Int): [Person!]!,
     person(id: ID!): Person,
     goods(limit: Int, offset: Int): [Goods!]!,
     good(id: ID!): Goods,
     locations: [Location!]!,
     location(id: ID!): Location,
     stockByGoods(goodsId: ID!): [Stock!]!,
     stockByLocation(locationId: ID!): [Stock!]!
   }
   
   type Mutation {
     createBill(input: BillInput!): Bill!
     postBill(id: ID!): Bill!
     createPayment(billId: ID!, amount: Float!): Payment!
     confirmPayment(id: ID!): Payment!
     # Person CRUD
     createPerson(input: PersonInput!): Person!
     updatePerson(id: ID!, input: PersonInput!): Person!
     deletePerson(id: ID!): Boolean!
     # Goods CRUD
     createGoods(input: GoodsInput!): Goods!
     updateGoods(id: ID!, input: GoodsInput!): Goods!
     deleteGoods(id: ID!): Boolean!
     # Location CRUD
     createLocation(input: LocationInput!): Location!
     updateLocation(id: ID!, input: LocationInput!): Location!
     deleteLocation(id: ID!): Boolean!
     # Stock CRUD
     createStock(input: StockInput!): Stock!
     updateStock(goodsId: ID!, locationId: ID!, input: StockInput!): Stock!
     deleteStock(goodsId: ID!, locationId: ID!): Boolean!
   }
  
  type Subscription {
    billCreated: Bill!
    paymentCreated: Payment!
    stockUpdated: Stock!
  }
  
  input BillInput { number: String!, lines: [BillLineInput!]! }
  input BillLineInput { goodId: ID!, quantity: Int!, price: Float! }
`;

const resolvers = {
  Query: {
    bills: async (_, { limit = 20, offset = 0 }, context) => {
      const now = Date.now();
      if (billsCache.data && now < billsCache.expiresAt) {
        return billsCache.data;
      }
      const res = await axios.get(`${REST_API}/bills`, {
        params: { limit, offset },
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      const data = Array.isArray(res.data) ? res.data : [];
      billsCache.data = data;
      billsCache.expiresAt = now + 5000; // 5 seconds TTL
      // Ensure fallback for missing lines field handled by client if needed
      return data;
    },
    bill: async (_, { id }, context) => {
      const res = await axios.get(`${REST_API}/bills/${id}`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      // If lines is missing, supply empty array
      return res.data && res.data.lines ? res.data : { lines: [], ...res.data };
    },
    payments: async (_, { limit = 20, offset = 0 }, context) => {
      const now = Date.now();
      if (paymentsCache.data && now < paymentsCache.expiresAt) {
        return paymentsCache.data;
      }
      const res = await axios.get(`${REST_API}/payments`, {
        params: { limit, offset },
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      const data = res.data;
      paymentsCache.data = data;
      paymentsCache.expiresAt = now + 5000; // 5 seconds TTL
      return data;
    },
    dashboard: async (_, __, context) => {
      const now = Date.now();
      if (dashboardCache.data && now < dashboardCache.expiresAt) {
        return dashboardCache.data;
      }
      const res = await axios.get(`${REST_API}/dashboard`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      dashboardCache.data = res.data;
      dashboardCache.expiresAt = now + 10000; // 10 seconds TTL
      return res.data;
    },
    balance: async (_, { accountId }, context) => {
      const now = Date.now();
      const cached = balanceCache[accountId];
      if (cached && now < cached.expiresAt) {
        return cached.data;
      }
      let result;
      try {
        const res = await axios.get(`${REST_API}/balances/${accountId}`, {
          headers: { Authorization: `Bearer ${context.token || ''}` }
        });
        const raw = res.data;
        let bal = 0;
        if (raw && typeof raw === 'object') {
          if (typeof raw.balance === 'number') bal = raw.balance;
          else if (typeof raw.amount === 'number') bal = raw.amount;
        } else if (typeof raw === 'number') {
          bal = raw;
        }
        result = { accountId, balance: Number(bal) };
      } catch (err) {
        // Fallback default balance in case REST BALANCE endpoint is unavailable
        result = { accountId, balance: 0 };
      }
      balanceCache[accountId] = { data: result, expiresAt: now + 5000 };
      return result;
    },
    payment: async (_, { id }, context) => {
      const res = await axios.get(`${REST_API}/payments/${id}`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      return res.data;
    },
    // Person queries
    persons: async (_, { limit = 20, offset = 0 }, context) => {
      const now = Date.now();
      if (personsCache.data && now < personsCache.expiresAt) {
        return personsCache.data;
      }
      const res = await axios.get(`${REST_API}/persons`, {
        params: { limit, offset },
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      const data = res.data;
      personsCache.data = data;
      personsCache.expiresAt = now + 5000;
      return data;
    },
    person: async (_, { id }, context) => {
      const res = await axios.get(`${REST_API}/persons/${id}`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      return res.data;
    },
    // Goods queries
    goods: async (_, { limit = 20, offset = 0 }, context) => {
      const now = Date.now();
      if (goodsCache.data && now < goodsCache.expiresAt) {
        return goodsCache.data;
      }
      const res = await axios.get(`${REST_API}/goods`, {
        params: { limit, offset },
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      const data = res.data;
      goodsCache.data = data;
      goodsCache.expiresAt = now + 5000;
      return data;
    },
    good: async (_, { id }, context) => {
      const res = await axios.get(`${REST_API}/goods/${id}`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      return res.data;
    },
    // Location queries
    locations: async (_, __, context) => {
      const res = await axios.get(`${REST_API}/locations`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      return res.data;
    },
    location: async (_, { id }, context) => {
      const res = await axios.get(`${REST_API}/locations/${id}`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      return res.data;
    },
    // Stock queries
    stockByGoods: async (_, { goodsId }, context) => {
      const res = await axios.get(`${REST_API}/stock/bygoods/${goodsId}`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      return res.data;
    },
    stockByLocation: async (_, { locationId }, context) => {
      const res = await axios.get(`${REST_API}/stock/bylocation/${locationId}`, {
        headers: { Authorization: `Bearer ${context.token || ''}` }
      });
      return res.data;
    }
  },
   Mutation: {
     createBill: async (_, { input }, context) => {
       const res = await axios.post(`${REST_API}/bills`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       // Invalidate bills cache after mutation
       billsCache.data = null;
       return res.data;
     },
     postBill: async (_, { id }, context) => {
       const res = await axios.put(`${REST_API}/bills/${id}`, { status: 'posted' }, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       // Invalidate bills cache after update
       billsCache.data = null;
       // Also invalidate payments cache and dashboard to reflect potential changes
       paymentsCache.data = null;
       dashboardCache.data = null;
       return res.data;
     },
     createPayment: async (_, { billId, amount }, context) => {
       const res = await axios.post(`${REST_API}/payments`, { billId, amount }, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       // Invalidate payments cache and dashboard (as payments may affect dashboard)
       paymentsCache.data = null;
       dashboardCache.data = null;
       return res.data;
     },
     confirmPayment: async (_, { id }, context) => {
       const res = await axios.put(`${REST_API}/payments/${id}/status`, { status: 'confirmed' }, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       // Invalidate payments cache and dashboard
       paymentsCache.data = null;
       dashboardCache.data = null;
       // Publish subscription event
       pubsub.publish('PAYMENT_CREATED', { paymentCreated: res.data });
       return res.data;
     },
     // Person CRUD mutations
     createPerson: async (_, { input }, context) => {
       const res = await axios.post(`${REST_API}/persons`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       personsCache.data = null;
       return res.data;
     },
     updatePerson: async (_, { id, input }, context) => {
       const res = await axios.put(`${REST_API}/persons/${id}`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       personsCache.data = null;
       return res.data;
     },
     deletePerson: async (_, { id }, context) => {
       await axios.delete(`${REST_API}/persons/${id}`, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       personsCache.data = null;
       return true;
     },
     // Goods CRUD mutations
     createGoods: async (_, { input }, context) => {
       const res = await axios.post(`${REST_API}/goods`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       goodsCache.data = null;
       return res.data;
     },
     updateGoods: async (_, { id, input }, context) => {
       const res = await axios.put(`${REST_API}/goods/${id}`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       goodsCache.data = null;
       return res.data;
     },
     deleteGoods: async (_, { id }, context) => {
       await axios.delete(`${REST_API}/goods/${id}`, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       goodsCache.data = null;
       return true;
     },
     // Location CRUD mutations
     createLocation: async (_, { input }, context) => {
       const res = await axios.post(`${REST_API}/locations`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       return res.data;
     },
     updateLocation: async (_, { id, input }, context) => {
       const res = await axios.put(`${REST_API}/locations/${id}`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       return res.data;
     },
     deleteLocation: async (_, { id }, context) => {
       await axios.delete(`${REST_API}/locations/${id}`, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       return true;
     },
     // Stock CRUD mutations
     createStock: async (_, { input }, context) => {
       const res = await axios.post(`${REST_API}/stock`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       // Invalidate relevant stock caches
       balanceCache = {};
       return res.data;
     },
     updateStock: async (_, { goodsId, locationId, input }, context) => {
       const res = await axios.put(`${REST_API}/stock/${goodsId}/${locationId}`, input, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       // Invalidate relevant stock caches
       balanceCache = {};
       return res.data;
     },
     deleteStock: async (_, { goodsId, locationId }, context) => {
       await axios.delete(`${REST_API}/stock/${goodsId}/${locationId}`, {
         headers: { Authorization: `Bearer ${context.token || ''}` }
       });
       // Invalidate relevant stock caches
       balanceCache = {};
       return true;
     }
   },
  Subscription: {
    billCreated: {
      subscribe: () => pubsub.asyncIterator(['BILL_CREATED'])
    },
    paymentCreated: {
      subscribe: () => pubsub.asyncIterator(['PAYMENT_CREATED'])
    },
    stockUpdated: {
      subscribe: () => pubsub.asyncIterator(['STOCK_UPDATED'])
    }
  }
};

const server = new ApolloServer({ 
  typeDefs, 
  resolvers, 
  context: ({ req }) => {
    const token = req.headers.authorization?.split(' ')[1] || null;
    return {
      token,
      ...createDataLoaders()
    };
  },
  introspection: true,
  playground: true
});

server.listen({ port: 4000 }).then(({ url }) => {
  console.log(`GraphQL proxy ready at ${url}`);
  console.log(`GraphQL Playground available at ${url}`);
});
