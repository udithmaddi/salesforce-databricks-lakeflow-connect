public class CrmPocDataGenerator implements Schedulable {

    // Change these numbers to create more or less data per run
    public static Integer NEW_ACCOUNTS = 2;
    public static Integer CONTACTS_PER_ACCOUNT = 2;
    public static Integer NEW_LEADS = 10;
    public static Integer NEW_OPPORTUNITIES = 5;
    public static Integer UPDATE_OPPORTUNITIES = 3;
    public static Integer UPDATE_LEADS = 3;
    public static Integer BAD_RECORD_CHANCE_PERCENT = 50;

    private static final String BAD_TAG = 'AUTO-GEN-BAD';

    private static final List<String> FIRST_NAMES = new List<String>{'Arjun','Priya','Ravi','Sneha','Karthik','Anjali','Vikram','Meera','Rahul','Divya','Suresh','Kavya','Manoj','Pooja','Naveen','Lakshmi'};
    private static final List<String> LAST_NAMES = new List<String>{'Reddy','Sharma','Iyer','Patel','Nair','Gupta','Rao','Menon','Singh','Das','Kumar','Joshi'};
    private static final List<String> TITLES = new List<String>{'CEO','CTO','Director of IT','Head of Operations','Purchase Manager','Sales Manager','Finance Manager','Project Lead','Analyst'};
    private static final List<String> COMPANY_PREFIX = new List<String>{'Nova','Apex','Trident','Vedanta','Indus','Bluechip','Sapphire','Zenith','Orion','Lotus','Horizon','Pinnacle'};
    private static final List<String> COMPANY_SUFFIX = new List<String>{'Foods','Textiles','Energy','Infra','Retail','Pharma','Solutions','Logistics','Healthcare','Motors'};
    private static final List<String> INDUSTRIES = new List<String>{'Technology','Banking','Healthcare','Retail','Energy','Manufacturing','Education','Telecommunications','Construction','Transportation'};
    private static final List<String> CITIES = new List<String>{'Hyderabad','Mumbai','Bengaluru','Chennai','Delhi','Pune','Kolkata','Ahmedabad'};
    private static final List<String> LEAD_SOURCES = new List<String>{'Web','Phone Inquiry','Partner Referral','Purchased List','Other'};
    private static final List<String> RATINGS = new List<String>{'Hot','Warm','Cold'};
    private static final List<String> LEAD_STATUSES = new List<String>{'Open - Not Contacted','Working - Contacted','Open - Not Contacted','Closed - Not Converted'};
    private static final List<String> OPEN_STAGES = new List<String>{'Prospecting','Qualification','Needs Analysis','Value Proposition','Id. Decision Makers','Perception Analysis','Proposal/Price Quote','Negotiation/Review'};
    private static final List<String> PROJECTS = new List<String>{'CRM Rollout','Data Platform','Mobile App','Security Audit','Analytics Suite','Cloud Migration','Annual Support'};
    private static final List<String> DEAL_TYPES = new List<String>{'New Customer','Existing Customer - Upgrade'};

    public void execute(SchedulableContext sc) {
        run();
    }

    public static String run() {
        errors = new List<String>();
        String today = String.valueOf(Date.today());
        List<Account> existing = [SELECT Id, Name FROM Account WHERE (Site = null OR Site != :BAD_TAG) LIMIT 200];
        Integer okAccounts = 0; Integer okContacts = 0; Integer okLeads = 0; Integer okOpps = 0; Integer badCount = 0;

        // 1. New good accounts with contacts
        List<Account> newAccounts = new List<Account>();
        for (Integer i = 1; i <= NEW_ACCOUNTS; i++) {
            String suffix = pick(COMPANY_SUFFIX);
            newAccounts.add(new Account(
                Name = pick(COMPANY_PREFIX) + ' ' + suffix + ' ' + today.replace('-', '').substring(2) + '-' + i,
                Industry = pick(INDUSTRIES),
                BillingCity = pick(CITIES),
                BillingCountry = 'India',
                NumberOfEmployees = 50 + rnd(5000)));
        }
        okAccounts = countOk(ins(newAccounts));

        List<Contact> newContacts = new List<Contact>();
        for (Account a : newAccounts) {
            if (a.Id == null) { continue; }
            for (Integer c = 1; c <= CONTACTS_PER_ACCOUNT; c++) {
                String fn = pick(FIRST_NAMES);
                String ln = pick(LAST_NAMES);
                newContacts.add(new Contact(
                    FirstName = fn, LastName = ln, AccountId = a.Id, Title = pick(TITLES),
                    Email = fn.toLowerCase() + '.' + ln.toLowerCase() + rnd(1000) + '@' + domainOf(a.Name),
                    MailingCity = pick(CITIES), MailingCountry = 'India'));
            }
        }
        okContacts = countOk(ins(newContacts));

        // 2. New good leads
        List<Lead> newLeads = new List<Lead>();
        for (Integer i = 0; i < NEW_LEADS; i++) {
            String fn = pick(FIRST_NAMES);
            String ln = pick(LAST_NAMES);
            String company = pick(COMPANY_PREFIX) + ' ' + pick(COMPANY_SUFFIX);
            newLeads.add(new Lead(
                FirstName = fn, LastName = ln, Company = company, Title = pick(TITLES),
                Email = fn.toLowerCase() + '.' + ln.toLowerCase() + rnd(10000) + '@' + domainOf(company),
                LeadSource = pick(LEAD_SOURCES), Status = pick(LEAD_STATUSES), Rating = pick(RATINGS),
                Industry = pick(INDUSTRIES), City = pick(CITIES), Country = 'India'));
        }
        okLeads = countOk(ins(newLeads));

        // 3. New good opportunities on existing accounts
        List<Opportunity> newOpps = new List<Opportunity>();
        if (!existing.isEmpty()) {
            for (Integer i = 0; i < NEW_OPPORTUNITIES; i++) {
                Account acc = existing[rnd(existing.size())];
                Integer roll = rnd(10);
                String stage; Date closeDate;
                if (roll < 3) { stage = 'Closed Won'; closeDate = Date.today().addDays(-rnd(30)); }
                else if (roll < 4) { stage = 'Closed Lost'; closeDate = Date.today().addDays(-rnd(30)); }
                else if (roll < 6) { stage = pick(OPEN_STAGES); closeDate = Date.today().addDays(-(1 + rnd(30))); }
                else { stage = pick(OPEN_STAGES); closeDate = Date.today().addDays(1 + rnd(120)); }
                newOpps.add(new Opportunity(
                    Name = acc.Name + ' - ' + pick(PROJECTS), AccountId = acc.Id, StageName = stage,
                    CloseDate = closeDate, Amount = (1 + rnd(50)) * 100000,
                    Type = pick(DEAL_TYPES), LeadSource = pick(LEAD_SOURCES)));
            }
        }
        okOpps = countOk(ins(newOpps));

        // 4. Bad records (each type is created with BAD_RECORD_CHANCE_PERCENT chance)
        if (!existing.isEmpty() && chance()) {
            Account copy = existing[rnd(existing.size())];
            badCount += countOk(ins(new List<Account>{ new Account(Name = copy.Name, Site = BAD_TAG, BillingCountry = 'India') }));
        }
        if (!existing.isEmpty() && chance()) {
            badCount += countOk(ins(new List<Opportunity>{ new Opportunity(
                Name = 'DQ Auto Negative Amount ' + today, AccountId = existing[rnd(existing.size())].Id,
                StageName = 'Prospecting', CloseDate = Date.today().addDays(30), Amount = -(1 + rnd(9)) * 1000) }));
        }
        if (chance()) {
            badCount += countOk(ins(new List<Opportunity>{ new Opportunity(
                Name = 'DQ Auto No Account ' + today, StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30), Amount = 10000) }));
        }
        if (chance()) {
            badCount += countOk(ins(new List<Contact>{ new Contact(
                FirstName = 'DQ Auto', LastName = 'Contact', Department = BAD_TAG) }));
        }
        if (chance()) {
            badCount += countOk(ins(new List<Lead>{ new Lead(
                FirstName = 'DQ Auto', LastName = 'Lead', Company = 'DQ Auto Lead ' + today,
                Status = 'Open - Not Contacted') }));
        }

        // 5. Updates to existing records
        Integer updatedOpps = updateOpportunities();
        Integer updatedLeads = updateLeads();

        // 6. Delete bad records created 2 or more days ago (shows deletes in the pipeline)
        Integer deleted = cleanupOldBadRecords();

        String summary = 'Created accounts=' + okAccounts + ', contacts=' + okContacts + ', leads=' + okLeads
            + ', opportunities=' + okOpps + ', bad records=' + badCount
            + ' | Updated opportunities=' + updatedOpps + ', leads=' + updatedLeads
            + ' | Deleted old bad records=' + deleted
            + (errors.isEmpty() ? '' : ' | First errors: ' + String.join(errors, ' ; '));
        System.debug(summary);
        return summary;
    }

    private static Integer updateOpportunities() {
        List<Opportunity> openOpps = [SELECT Id FROM Opportunity WHERE IsClosed = false AND AccountId != null LIMIT 100];
        List<Opportunity> changes = new List<Opportunity>();
        Set<Id> used = new Set<Id>();
        Integer tries = 0;
        while (changes.size() < UPDATE_OPPORTUNITIES && !openOpps.isEmpty() && tries < 50) {
            tries++;
            Opportunity o = openOpps[rnd(openOpps.size())];
            if (used.contains(o.Id)) { continue; }
            used.add(o.Id);
            Integer roll = rnd(10);
            Opportunity upd = new Opportunity(Id = o.Id);
            if (roll < 4) { upd.StageName = 'Closed Won'; upd.CloseDate = Date.today(); }
            else if (roll < 6) { upd.StageName = 'Closed Lost'; upd.CloseDate = Date.today(); }
            else { upd.StageName = pick(OPEN_STAGES); }
            changes.add(upd);
        }
        return countOk(Database.update(changes, false));
    }

    private static Integer updateLeads() {
        List<Lead> openLeads = [SELECT Id FROM Lead WHERE IsConverted = false AND Status = 'Open - Not Contacted' LIMIT 100];
        List<Lead> changes = new List<Lead>();
        Set<Id> used = new Set<Id>();
        Integer tries = 0;
        while (changes.size() < UPDATE_LEADS && !openLeads.isEmpty() && tries < 50) {
            tries++;
            Lead l = openLeads[rnd(openLeads.size())];
            if (used.contains(l.Id)) { continue; }
            used.add(l.Id);
            changes.add(new Lead(Id = l.Id, Status = 'Working - Contacted'));
        }
        return countOk(Database.update(changes, false));
    }

    private static Integer cleanupOldBadRecords() {
        Datetime cutoff = Datetime.now().addDays(-2);
        List<Opportunity> oldOpps = [SELECT Id FROM Opportunity WHERE Name LIKE 'DQ Auto%' AND CreatedDate < :cutoff];
        List<Contact> oldContacts = [SELECT Id FROM Contact WHERE Department = :BAD_TAG AND CreatedDate < :cutoff];
        List<Lead> oldLeads = [SELECT Id FROM Lead WHERE Company LIKE 'DQ Auto%' AND CreatedDate < :cutoff];
        List<Account> oldAccounts = [SELECT Id FROM Account WHERE Site = :BAD_TAG AND CreatedDate < :cutoff];
        Integer n = 0;
        for (Database.DeleteResult r : Database.delete(oldOpps, false)) { if (r.isSuccess()) { n++; } }
        for (Database.DeleteResult r : Database.delete(oldContacts, false)) { if (r.isSuccess()) { n++; } }
        for (Database.DeleteResult r : Database.delete(oldLeads, false)) { if (r.isSuccess()) { n++; } }
        for (Database.DeleteResult r : Database.delete(oldAccounts, false)) { if (r.isSuccess()) { n++; } }
        return n;
    }

    private static Integer rnd(Integer maxExclusive) {
        return Math.mod(Math.mod(Crypto.getRandomInteger(), maxExclusive) + maxExclusive, maxExclusive);
    }

    private static String pick(List<String> items) {
        return items[rnd(items.size())];
    }

    private static Boolean chance() {
        return rnd(100) < BAD_RECORD_CHANCE_PERCENT;
    }

    private static String domainOf(String companyName) {
        return companyName.toLowerCase().replaceAll('[^a-z0-9]', '') + '.com';
    }

    private static List<String> errors = new List<String>();

    private static List<Database.SaveResult> ins(List<SObject> records) {
        Database.DMLOptions opts = new Database.DMLOptions();
        opts.DuplicateRuleHeader.allowSave = true;
        opts.OptAllOrNone = false;
        return Database.insert(records, opts);
    }

    private static Integer countOk(List<Database.SaveResult> results) {
        Integer n = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                n++;
            } else if (errors.size() < 5) {
                Database.Error e = r.getErrors()[0];
                errors.add(String.valueOf(e.getStatusCode()) + ': ' + e.getMessage());
            }
        }
        return n;
    }
}
