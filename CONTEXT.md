# Sure

Sure is a global personal finance product for a household to understand and
manage its shared financial life while preserving the financial practices of
the regions in which that household lives.

## Product Scope

**Global Financial Core**:
The country-neutral financial concepts and invariants shared by every Family,
regardless of locale or provider.
_Avoid_: Western default, Indonesian default

**Regional Financial Practice**:
A financial product, convention, institution, or workflow used in a particular
market and expressed through the Global Financial Core.
_Avoid_: Global default, special-case product architecture

**Regional Coverage**:
The explicit languages, currencies, providers, terminology, examples, and
financial practices supported for a region. Indonesia and Southeast Asia are
first-class Regional Coverage, not the universal default.
_Avoid_: Country fork, translation only

## Household

**Family**:
The authoritative household boundary that owns the shared financial record and
determines which financial facts belong together.
_Avoid_: Tenant, workspace, organization, account

**User**:
A person who belongs to a Family and acts within the permissions granted to
them. A User is not the owner boundary of the shared financial record.
_Avoid_: Account, customer, tenant

**Family Member**:
A User who can view and manage the complete shared financial record of their
Family but cannot administer Family membership, integrations, security,
billing, or household-wide settings.
_Avoid_: Read-only user, account guest

**Family Admin**:
A User who can manage the shared financial record and administer membership,
integrations, security, billing, and household-wide settings for their Family.
_Avoid_: Owner, tenant admin, super admin

## Recurring Finance

**Recurring Hub**:
The user-facing area where a Family reviews recurring financial activity,
including Recurring Patterns and Subscriptions.
_Avoid_: Subscription Manager

**Recurring Pattern**:
A repeated transaction, income event, or transfer pattern that Sure detects or
a Family confirms.
_Avoid_: Subscription, recurring transaction

**Subscription**:
A Family's continuing paid commitment to a Service.
_Avoid_: Recurring Pattern, Sure Membership, plan

**Renewal**:
One billing or payment cycle of a Subscription.
_Avoid_: Subscription, recurring transaction

**Service**:
A catalog identity for an organization or utility that may provide a
Subscription; it is not itself part of a Family's financial record.
_Avoid_: Merchant, Subscription

**Sure Membership**:
A Family's entitlement to managed Sure product services.
_Avoid_: Subscription, Subscription Plan

**Application Mode**:
The operational environment in which Sure runs, either Managed or Self Hosted;
it does not change the meaning of a Family's financial record.
_Avoid_: Pricing plan, financial feature tier

## Financial Record

**Entry**:
A dated financial fact recorded against an Account, such as a Transaction,
Valuation, or Trade.
_Avoid_: Balance, activity row

**Transaction**:
A dated flow of value between a Family Account and an external party.
_Avoid_: Transfer, Valuation

**Transfer**:
A movement of value between two Accounts in the same Family that is neither
income nor expense.
_Avoid_: Transaction, income, expense

**Inflow**:
Value entering an Account.
_Avoid_: Negative amount

**Outflow**:
Value leaving an Account.
_Avoid_: Positive amount

**Balance Anchor**:
An Account balance that was directly observed or explicitly confirmed for a
specific date.
_Avoid_: Balance Snapshot, current balance

**Balance Snapshot**:
A derived daily Account balance that can be rebuilt from financial facts and
anchors.
_Avoid_: Balance Anchor, ledger entry

**Current Balance**:
The latest projected Account balance used for present-day display.
_Avoid_: Historical source of truth, Balance Anchor

**Holding Snapshot**:
An observed investment position at a specific date, whether or not complete
Trade history is available.
_Avoid_: Trade, security transaction

**Trade**:
A dated investment activity that changes or describes an investment position;
it is not necessarily a complete history of that position.
_Avoid_: Holding Snapshot, Transaction

**Reconciliation**:
An explicit, auditable alignment between calculated financial state and an
observed state.
_Avoid_: Silent correction, history rewrite

**Data Provenance**:
The origin and identity of a financial fact, including its source, external
identity when present, effective time, and observation time.
_Avoid_: Audit Log, sync status

**Review Item**:
An unresolved conflict or ambiguity that could materially change a Family's
financial record and requires an explicit decision.
_Avoid_: Validation error, notification

**Enrichment**:
Derived descriptive information, such as normalized merchants or suggested
categories, that does not replace the underlying financial fact.
_Avoid_: Source data, manual correction

## AI

**AI Processing**:
An explicitly enabled use of an external or self-hosted model to analyze selected
Family information for a stated purpose.
_Avoid_: Anonymous processing, automatic consent

**AI Suggestion**:
AI-generated advice or Enrichment that does not change a material financial fact
until a User explicitly confirms it.
_Avoid_: Financial fact, automatic correction

**AI Provider**:
The configured model service that performs AI Processing under a disclosed data
and retention policy.
_Avoid_: Model, assistant

**Reporting Currency**:
The currency a Family chooses for aggregated reports and presentation; it does
not replace the original currency of a financial fact.
_Avoid_: Base storage currency, Account currency

**Exchange Rate Observation**:
An observed conversion rate between two currencies for a specific effective
date.
_Avoid_: Current rate, implicit fallback

## Assets And Debts

**Account**:
A record of one financial position held by or owed by a Family.
_Avoid_: User, login, provider connection

**Asset**:
A resource with economic value controlled by a Family.
_Avoid_: Available credit, income

**Liability**:
A present obligation of a Family to another party.
_Avoid_: Expense, credit limit

**Receivable**:
An Asset representing money owed to a Family.
_Avoid_: Personal debt, borrowed money

**Debt Agreement**:
A Liability representing principal and repayment obligations owed by a Family
to a lender or financier.
_Avoid_: Receivable, Personal Lending

**Secured Debt**:
A Debt Agreement backed by Collateral.
_Avoid_: Mortgage, secured asset

**Collateral**:
An Asset pledged to secure a Debt Agreement.
_Avoid_: Debt, installment

**Mortgage**:
A Secured Debt whose Collateral is Property.
_Avoid_: Property, rent

**Vehicle Financing**:
A Secured Debt whose Collateral is a Vehicle.
_Avoid_: Vehicle, lease payment

**Consumer Financing**:
A Debt Agreement used to acquire a consumer good without a reusable revolving
credit facility.
_Avoid_: PayLater, Subscription

**PayLater**:
A reusable buy-now-pay-later credit facility whose utilized amount is a
Liability; its credit limit and available credit are not Assets.
_Avoid_: Consumer Financing, Asset

**Personal Lending**:
A Receivable created when a Family lends money to another person.
_Avoid_: Borrowing, Debt Agreement

**Installment Schedule**:
The planned sequence of payments for a Debt Agreement.
_Avoid_: Payment history, Subscription schedule

**Installment**:
One scheduled payment obligation within an Installment Schedule.
_Avoid_: Transaction, Renewal

**Principal Payment**:
The portion of a Debt Agreement payment that reduces principal and transfers
value from cash to reduce a Liability.
_Avoid_: Expense, interest

**Financing Cost**:
Interest, margin, or fees paid for a Debt Agreement and recognized as expense.
_Avoid_: Principal Payment

**Financing Structure**:
The contractual method used by a Debt Agreement, including conventional and
Sharia-compliant structures such as Murabaha or Ijarah.
_Avoid_: Account type, Debt classification

## Precious Metals

**Precious Metal**:
A physical or custodial metal asset measured by quantity and unit. Gold is one
kind of Precious Metal.
_Avoid_: Gold account, Security

**Precious Metal Position**:
The quantity of a Precious Metal held by a Family.
_Avoid_: Balance, Valuation

**Metal Activity**:
A dated purchase, sale, fee, or quantity adjustment affecting a Precious Metal
Position.
_Avoid_: Trade, Valuation

**Quantity Anchor**:
A Precious Metal quantity directly observed or explicitly confirmed for a
specific date.
_Avoid_: Metal Activity, Current Balance

**Market Price Observation**:
An observed price per unit of an asset in a stated currency on a specific date.
_Avoid_: Valuation, purchase price

**Metal Valuation**:
The derived monetary value of a Precious Metal Position using a Market Price
Observation and any required currency conversion.
_Avoid_: Purchase cost, Metal Activity
