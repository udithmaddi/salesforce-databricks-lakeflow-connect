// Run once now to test (creates data immediately):
CrmPocDataGenerator.run();

// Run this once to schedule it every day at 5:00 AM (time zone of your Salesforce user):
System.schedule('CRM POC Daily Data Generator', '0 0 5 * * ?', new CrmPocDataGenerator());
