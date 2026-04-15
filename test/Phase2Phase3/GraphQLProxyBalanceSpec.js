// Simple integration test for GraphQL proxy balance query
const fetch = (() => {
  try {
    return require('node-fetch');
  } catch (e) {
    if (typeof globalThis.fetch === 'function') return globalThis.fetch.bind(globalThis);
    throw e;
  }
})();

(async () => {
  const url = 'http://localhost:4000/'; // GraphQL proxy
  const query = `query BalanceQuery($id: ID!) { balance(accountId: $id) { accountId, balance } }`;
  const variables = { id: "4001" };
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, variables })
  });
  const json = await res.json();
  console.log('GraphQL Balance Response:', JSON.stringify(json, null, 2));
  if (!json.data || !json.data.balance) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}).catch(err => {
  console.error('GraphQL Balance Proxy test failed', err);
  process.exit(2);
});
