const { ApolloServer, gql } = require('apollo-server');
const axios = require('axios');

const REST_API = process.env.REST_API_URL || 'http://surypus-api:8080/api/v1';

let dashboardCache = { data: null, expiresAt: 0 };
let billsCache = { data: null, expiresAt: 0 };
let paymentsCache = { data: null, expiresAt: 0 };
let balanceCache = {};

const typeDefs = gql`
  type BillLine { id: ID!, goodId: ID!, quantity: Int!, price: Float!, amount: Float! }
  type Bill { id: ID!, number: String!, date: String, currency: String, total_amount: Float, status: String!, lines: [BillLine!]! }
  type Payment { id: ID!, billId: ID!, amount: Float!, status: String!, createdAt: String }
  type Dashboard { revenue: Float, stockValue: Float, pendingPayments: Int }
  type Balance { accountId: ID!, balance: Float! }
  type Query { bills(limit: Int, offset: Int): [Bill!]!, bill(id: ID!): Bill, payments(limit: Int, offset: Int): [Payment!]!, payment(id: ID!): Payment, dashboard: Dashboard, balance(accountId: ID!): Balance }
  type Mutation {
    createBill(input: BillInput!): Bill!
    postBill(id: ID!): Bill!
    createPayment(billId: ID!, amount: Float!): Payment!
    confirmPayment(id: ID!): Payment!
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
      return res.data;
    }
  }
};

const server = new ApolloServer({ typeDefs, resolvers, context: ({ req }) => {
  const token = req.headers.authorization?.split(' ')[1] || null;
  return { token };
} });

server.listen({ port: 4000 }).then(({ url }) => {
  console.log(`GraphQL proxy ready at ${url}`);
});
