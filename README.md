# bamboohr-entraid-synchronisation

This Azure Logic app synchronises user information such as phone numbers and job titles from BambooHR into Entra ID.

## Prerequisites

### Entra ID

In the [Microsoft Entra Admin Center](https://entra.microsoft.com/), go to *Applications* -> *App
registrations* and create a new app registration to be used by this Logic app. Click *API permissions*
and then *Add a permission*. Select *Microsoft Graph* then *Application permissions*. Add the
`User.ReadWrite.All` permission and then click *Grant admin consent* for your organisation. Click
*Certificates & secrets* and create a new client secret. Create a new client secret (under
*Certificates & secrets*). Record both the secret value and secret ID, to provide as input variables
to the Bicep deployment template.

The app registration must be granted an Entra ID administrator role to be able to update the business phone and mobile phone fields, as these are considered sensitive properties within Entra ID. Within the Microsoft Entra Admin Center, go to *Roles & admins* -> *Roles & admins*, select the *Privileged Authentication Administrator* role, and add a new assignment for the app registration you have created.

### BambooHR

This app uses the BambooHR company directory API, meaning that the information available to it is limited by your [BambooHR company directory configuration](https://amach.bamboohr.com/settings/directory.php). If, for example, the *Mobile Phone* field is disabled in the BambooHR company directory settings, it will not be synchronised into Entra ID.

Create a new custom access level. Under *What this Access Level Can Do* leave all options unselected. Under *What this Access Level Can See* set the *Personal* and *Job* fields to View Only. Set this access level to apply to *All Employees*. Then add a non-employee BambooHR user under your new custom access level. Log in as that user and create a BambooHR API key. Record that key to provide as an input variable to the Bicep deployment template.

## Parameters

* `location` - Azure region to deploy into
* `workloadName` - workload label to be used in resource names
* `appRegistrationClientId` - Entra ID app registration client ID
* `EntraIDAppRegistrationSecretValue` - Entra ID app registration secret value
* `bambooHRApiKey` - BambooHR API key
* `keyVaultSecretsOfficerObjectId` (optional) - ID of an Entra ID group to be granted administrative
   privileges over secrets in the key vault
* `logAnalyticsWorkspaceId` (options) - ID of an Azure Log Analytics workspace to send logs to

## Field Mappings

| BambooHR         | Entra ID            |
|------------------|---------------------|
| department       | department          |
| division         | companyName         |
| employmentStatus | employeeType        |
| hireDate         | employeeHireDate    |
| jobTitle         | jobTitle            |
| location         | country             |
| location         | extensionAttribute1 |
| mobilePhone      | mobilePhone         |
| workPhone        | businessPhones      |
