const { closePool } = require('../src/db');
const { createService } = require('../src/dao/serviceDao');

// Demo data, not inferred from Figma. Every tag has a different initial (it is the first letter of the ticket code).
const DEMO_SERVICES = [
  { tag: 'Shipping', serviceTime: 5 },
  { tag: 'Deposit', serviceTime: 8 },
  { tag: 'Accounts', serviceTime: 10 },
];

// creates the demo services; the ones that already exist (or clash on the initial) are skipped
async function seed() {
  for (const { tag, serviceTime } of DEMO_SERVICES) {
    try {
      await createService(tag, serviceTime);
      console.log(`Created service "${tag}"`);
    } catch (error) {
      console.log(`Skipped "${tag}": ${error.message}`);
    }
  }
}

if (require.main === module) {
  seed().then(() => console.log('Demo services ready'))
    .catch((error) => { console.error(error.message); process.exitCode = 1; })
    .finally(closePool);
}

module.exports = { seed };
