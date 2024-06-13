@description('Azure region to deploy into')
param location string

@description('Workload name')
param workloadName string

@description('Application (client) ID for Entra ID app registration')
param appRegistrationClientId string

@description('Azure Key Vault name')
param keyVaultName string

@description('Fully-qualified ID of Azure Log Analytics workspace for logging')
param logAnalyticsWorkspaceId string = ''

var tenantId = tenant().tenantId

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${workloadName}-workflow'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
        appRegistrationClientId: {
          defaultValue: appRegistrationClientId
          type: 'String'
        }
        tenantId: {
          defaultValue: tenantId
          type: 'String'
        }
      }
      triggers: {
        Recurrence: {
          recurrence: {
            frequency: 'Day'
            interval: 1
            schedule: {
              hours: [
                '4'
              ]
            }
          }
          evaluatedRecurrence: {
            frequency: 'Day'
            interval: 1
            schedule: {
              hours: [
                '4'
              ]
            }
          }
          type: 'Recurrence'
        }
      }
      actions: {
        Apply_to_each_active_BambooHR_employee: {
          actions: {
            Check_whether_workPhone_provided_by_BambooHR: {
              actions: {
                Check_whether_workPhoneExtension_provided_by_BambooHR: {
                  actions: {
                    Set_BusinessPhones_with_extension: {
                      inputs: {
                        name: 'BusinessPhones'
                        value: [
                          '@{items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhone\']} Ext. @{items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhoneExtension\']}'
                        ]
                      }
                      type: 'SetVariable'
                    }
                  }
                  else: {
                    actions: {
                      Set_BusinessPhones_without_extension: {
                        inputs: {
                          name: 'BusinessPhones'
                          value: [
                            '@items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhone\']'
                          ]
                        }
                        type: 'SetVariable'
                      }
                    }
                  }
                  expression: {
                    and: [
                      {
                        not: {
                          equals: [
                            '@items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhoneExtension\']'
                            '@null'
                          ]
                        }
                      }
                    ]
                  }
                  type: 'If'
                }
              }
              else: {
                actions: {
                  Set_empty_BusinessPhones: {
                    inputs: {
                      name: 'BusinessPhones'
                      value: []
                    }
                    type: 'SetVariable'
                  }
                }
              }
              expression: {
                and: [
                  {
                    not: {
                      equals: [
                        '@items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhone\']'
                        '@null'
                      ]
                    }
                  }
                ]
              }
              runAfter: {
                Switch: [
                  'Succeeded'
                ]
              }
              type: 'If'
            }
            Find_direct_reports: {
              inputs: {
                from: '@body(\'Filter_for_active_BambooHR_employees\')'
                where: '@equals(item()?[\'supervisor\'], items(\'Apply_to_each_active_BambooHR_employee\')?[\'displayName\'])'
              }
              runAfter: {
                Set_Entra_ID_user_properties: [
                  'Succeeded'
                ]
              }
              type: 'Query'
            }
            For_each: {
              actions: {
                Set_manager: {
                  inputs: {
                    authentication: {
                      audience: 'https://graph.microsoft.com/'
                      clientId: '@parameters(\'appRegistrationClientId\')'
                      secret: '@body(\'Get_Entra_ID_app_registration_secret\')?[\'value\']'
                      tenant: '@parameters(\'tenantId\')'
                      type: 'ActiveDirectoryOAuth'
                    }
                    body: {
                      '@@odata.id': 'https://graph.microsoft.com/v1.0/users/@{body(\'Parse_Entra_ID_user\')?[\'id\']}'
                    }
                    headers: {
                      'Content-Type': 'application/json'
                    }
                    method: 'PUT'
                    uri: 'https://graph.microsoft.com/v1.0/users/@{items(\'For_each\')[\'workEmail\']}/manager/$ref'
                  }
                  type: 'Http'
                }
              }
              foreach: '@body(\'Parse_direct_reports\')'
              runAfter: {
                Parse_direct_reports: [
                  'Succeeded'
                ]
              }
              type: 'Foreach'
            }
            Get_Entra_ID_user: {
              inputs: {
                authentication: {
                  audience: 'https://graph.microsoft.com/'
                  clientId: '@parameters(\'appRegistrationClientId\')'
                  secret: '@body(\'Get_Entra_ID_app_registration_secret\')?[\'value\']'
                  tenant: '@parameters(\'tenantId\')'
                  type: 'ActiveDirectoryOAuth'
                }
                headers: {
                  'Content-Type': 'application/json'
                }
                method: 'GET'
                uri: 'https://graph.microsoft.com/v1.0/users/@{items(\'Apply_to_each_active_BambooHR_employee\')?[\'workEmail\']}'
              }
              runAfter: {
                Check_whether_workPhone_provided_by_BambooHR: [
                  'Succeeded'
                ]
              }
              type: 'Http'
            }
            Parse_Entra_ID_user: {
              inputs: {
                content: '@body(\'Get_Entra_ID_user\')'
                schema: {
                  properties: {
                    businessPhones: {
                      items: {
                        type: 'string'
                      }
                      type: 'array'
                    }
                    displayName: {
                      type: 'string'
                    }
                    givenName: {
                      type: 'string'
                    }
                    id: {
                      type: 'string'
                    }
                    jobTitle: {
                      anyOf: [
                        {
                          type: 'null'
                        }
                        {
                          type: 'string'
                        }
                      ]
                    }
                    mail: {
                      type: 'string'
                    }
                    mobilePhone: {
                      anyOf: [
                        {
                          type: 'null'
                        }
                        {
                          type: 'string'
                        }
                      ]
                    }
                    officeLocation: {
                      anyOf: [
                        {
                          type: 'null'
                        }
                        {
                          type: 'string'
                        }
                      ]
                    }
                    preferredLanguage: {
                      anyOf: [
                        {
                          type: 'null'
                        }
                        {
                          type: 'string'
                        }
                      ]
                    }
                    surname: {
                      type: 'string'
                    }
                    userPrincipalName: {
                      type: 'string'
                    }
                  }
                  type: 'object'
                }
              }
              runAfter: {
                Get_Entra_ID_user: [
                  'Succeeded'
                ]
              }
              type: 'ParseJson'
            }
            Parse_direct_reports: {
              inputs: {
                content: '@body(\'Find_direct_reports\')'
                schema: {
                  items: {
                    properties: {
                      canUploadPhoto: {
                        type: 'integer'
                      }
                      department: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      displayName: {
                        type: 'string'
                      }
                      division: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      firstName: {
                        type: 'string'
                      }
                      id: {
                        type: 'string'
                      }
                      jobTitle: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      lastName: {
                        type: 'string'
                      }
                      linkedIn: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      location: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      mobilePhone: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      photoUploaded: {
                        type: 'boolean'
                      }
                      photoUrl: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      preferredName: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      pronouns: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      supervisor: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workEmail: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workPhone: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workPhoneExtension: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                    }
                    required: [
                      'id'
                      'displayName'
                      'firstName'
                      'lastName'
                      'preferredName'
                      'jobTitle'
                      'workEmail'
                      'department'
                      'location'
                      'division'
                      'linkedIn'
                      'pronouns'
                      'supervisor'
                      'photoUploaded'
                      'canUploadPhoto'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
              }
              runAfter: {
                Find_direct_reports: [
                  'Succeeded'
                ]
              }
              type: 'ParseJson'
            }
            Retrieve_additional_employee_details_from_BambooHR: {
              inputs: {
                authentication: {
                  password: '@{body(\'Get_BambooHR_API_key_secret\')?[\'value\']}'
                  type: 'Basic'
                  username: '@{body(\'Get_BambooHR_API_key_secret\')?[\'value\']}'
                }
                headers: {
                  Accept: 'application/json'
                }
                method: 'GET'
                queries: {
                  fields: 'hireDate'
                }
                uri: 'https://api.bamboohr.com/api/gateway.php/amach/v1/employees/@{items(\'Apply_to_each_active_BambooHR_employee\')?[\'id\']}'
              }
              runtimeConfiguration: {
                contentTransfer: {
                  transferMode: 'Chunked'
                }
              }
              type: 'Http'
            }
            Retrieve_employment_status_from_BambooHR: {
              inputs: {
                authentication: {
                  password: '@{body(\'Get_BambooHR_API_key_secret\')?[\'value\']}'
                  type: 'Basic'
                  username: '@{body(\'Get_BambooHR_API_key_secret\')?[\'value\']}'
                }
                headers: {
                  Accept: 'application/json'
                }
                method: 'GET'
                uri: 'https://api.bamboohr.com/api/gateway.php/amach/v1/employees/@{items(\'Apply_to_each_active_BambooHR_employee\')?[\'id\']}/tables/employmentStatus'
              }
              runAfter: {
                Retrieve_additional_employee_details_from_BambooHR: [
                  'Succeeded'
                ]
              }
              runtimeConfiguration: {
                contentTransfer: {
                  transferMode: 'Chunked'
                }
              }
              type: 'Http'
            }
            Set_Entra_ID_user_properties: {
              inputs: {
                authentication: {
                  audience: 'https://graph.microsoft.com/'
                  clientId: '@parameters(\'appRegistrationClientId\')'
                  secret: '@body(\'Get_Entra_ID_app_registration_secret\')?[\'value\']'
                  tenant: '@parameters(\'tenantId\')'
                  type: 'ActiveDirectoryOAuth'
                }
                body: {
                  businessPhones: '@variables(\'BusinessPhones\')'
                  companyName: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'division\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'division\'])'
                  country: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'location\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'location\'])'
                  department: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'department\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'department\'])'
                  employeeHireDate: '@formatDateTime(body(\'Retrieve_additional_employee_details_from_BambooHR\')[\'hireDate\'], \'yyyy-MM-ddTHH:mmZ\')'
                  employeeType: '@variables(\'EmploymentStatus\')'
                  jobTitle: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'jobTitle\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'jobTitle\'])'
                  mobilePhone: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'mobilePhone\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'mobilePhone\'])'
                  onPremisesExtensionAttributes: {
                    extensionAttribute1: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'location\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'location\'])'
                    extensionAttribute2: '@variables(\'EmploymentStatus\')'
                  }
                }
                headers: {
                  'Content-Type': 'application/json'
                }
                method: 'PATCH'
                uri: 'https://graph.microsoft.com/v1.0/users/@{items(\'Apply_to_each_active_BambooHR_employee\')?[\'workEmail\']}'
              }
              runAfter: {
                Parse_Entra_ID_user: [
                  'Succeeded'
                ]
              }
              type: 'Http'
            }
            Switch: {
              cases: {
                'Contractor_-_C': {
                  actions: {
                    'Set_EmploymentStatus_to_Contractor_for_Contractor_-_C': {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Contractor - C'
                }
                'Contractor_-_Individual_Entrepreneur': {
                  actions: {
                    'Set_EmploymentStatus_to_Contractor_for_Contractor_-_Individual_Entrepreneur': {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Contractor - Individual Entrepreneur'
                }
                'Contractor_-_Limited_Company': {
                  actions: {
                    'Set_EmploymentStatus_to_Contractor_for_Contractor_-_Limited_Company': {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Contractor - Limited Company'
                }
                'Contractor_-_PFA': {
                  actions: {
                    'Set_EmploymentStatus_to_Contractor_for_Contractor_-_PFA': {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Contractor - PFA'
                }
                'Contractor_-_Sole_Trader': {
                  actions: {
                    'Set_EmploymentStatus_to_Contractor_for_Contractor_-_Sole_Trader': {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Contractor - Sole Trader'
                }
                FTC: {
                  actions: {
                    Set_EmploymentStatus_to_Contractor_for_FTC: {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'FTC'
                }
                'Limited_Partnership_(LP)': {
                  actions: {
                    'Set_EmploymentStatus_to_Contractor_for_Limited_Partnership_(LP)': {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Limited Partnership (LP)'
                }
                Maternity_Leave: {
                  actions: {
                    Set_EmploymentStatus_to_Employee_for_Maternity_Leave: {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Employee'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Maternity Leave'
                }
                'Part-Time': {
                  actions: {
                    'Set_EmploymentStatus_to_Employee_for_Part-Time': {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Employee'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Part-Time'
                }
                Partner: {
                  actions: {
                    Set_EmploymentStatus_to_Contractor_for_Partner: {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Partner'
                }
                'Partner_-_C': {
                  actions: {
                    'Set_employment_status_to_Contractor_for_Partner_-_C': {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Contractor'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Partner - C'
                }
                Permanent: {
                  actions: {
                    Set_EmploymentStatus_to_Employee_for_Permanent: {
                      inputs: {
                        name: 'EmploymentStatus'
                        value: 'Employee'
                      }
                      type: 'SetVariable'
                    }
                  }
                  case: 'Permanent'
                }
              }
              default: {
                actions: {
                  Set_EmploymentStatus_to_unknown: {
                    inputs: {
                      name: 'EmploymentStatus'
                      value: 'Unknown'
                    }
                    type: 'SetVariable'
                  }
                }
              }
              expression: '@{body(\'Retrieve_employment_status_from_BambooHR\')[0][\'employmentStatus\']}'
              runAfter: {
                Retrieve_employment_status_from_BambooHR: [
                  'Succeeded'
                ]
              }
              type: 'Switch'
            }
          }
          foreach: '@body(\'Filter_for_active_BambooHR_employees\')'
          runAfter: {
            Initialise_EmploymentStatus_variable: [
              'Succeeded'
            ]
          }
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
          type: 'Foreach'
        }
        Filter_for_active_BambooHR_employees: {
          inputs: {
            from: '@body(\'Parse_BambooHR_directory_response\')?[\'employees\']'
            where: '@not(equals(item()?[\'workEmail\'], null))'
          }
          runAfter: {
            Parse_BambooHR_directory_response: [
              'Succeeded'
            ]
          }
          type: 'Query'
        }
        Get_BambooHR_API_key_secret: {
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'${workloadName}-bamboohrapikey-secret\')}/value'
          }
          runAfter: {}
          runtimeConfiguration: {
            secureData: {
              properties: [
                'outputs'
              ]
            }
          }
          type: 'ApiConnection'
        }
        Get_Entra_ID_app_registration_secret: {
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'${workloadName}-appregistration-secret\')}/value'
          }
          runAfter: {}
          runtimeConfiguration: {
            secureData: {
              properties: [
                'outputs'
              ]
            }
          }
          type: 'ApiConnection'
        }
        Initialise_BusinessPhones_variable: {
          inputs: {
            variables: [
              {
                name: 'BusinessPhones'
                type: 'array'
              }
            ]
          }
          runAfter: {
            Filter_for_active_BambooHR_employees: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
        }
        Initialise_EmploymentStatus_variable: {
          inputs: {
            variables: [
              {
                name: 'EmploymentStatus'
                type: 'string'
              }
            ]
          }
          runAfter: {
            Initialise_BusinessPhones_variable: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
        }
        Parse_BambooHR_directory_response: {
          inputs: {
            content: '@body(\'Retrieve_company_directory_from_BambooHR\')'
            schema: {
              properties: {
                employees: {
                  items: {
                    properties: {
                      canUploadPhoto: {
                        type: 'integer'
                      }
                      department: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      displayName: {
                        type: 'string'
                      }
                      division: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      firstName: {
                        type: 'string'
                      }
                      id: {
                        type: 'string'
                      }
                      jobTitle: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      lastName: {
                        type: 'string'
                      }
                      linkedIn: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      location: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      mobilePhone: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      photoUploaded: {
                        type: 'boolean'
                      }
                      photoUrl: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      preferredName: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      pronouns: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      supervisor: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workEmail: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workPhone: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workPhoneExtension: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                    }
                    required: [
                      'id'
                      'displayName'
                      'firstName'
                      'lastName'
                      'preferredName'
                      'jobTitle'
                      'workEmail'
                      'department'
                      'location'
                      'division'
                      'linkedIn'
                      'pronouns'
                      'supervisor'
                      'photoUploaded'
                      'canUploadPhoto'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
                fields: {
                  items: {
                    properties: {
                      id: {
                        type: 'string'
                      }
                      name: {
                        type: 'string'
                      }
                      type: {
                        type: 'string'
                      }
                    }
                    required: [
                      'id'
                      'type'
                      'name'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
              }
              type: 'object'
            }
          }
          runAfter: {
            Retrieve_company_directory_from_BambooHR: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
        }
        Retrieve_company_directory_from_BambooHR: {
          inputs: {
            authentication: {
              password: '@body(\'Get_BambooHR_API_key_secret\')?[\'value\']'
              type: 'Basic'
              username: '@body(\'Get_BambooHR_API_key_secret\')?[\'value\']'
            }
            headers: {
              Accept: 'application/json'
            }
            method: 'GET'
            uri: 'https://api.bamboohr.com/api/gateway.php/amach/v1/employees/directory'
          }
          runAfter: {
            Get_BambooHR_API_key_secret: [
              'Succeeded'
            ]
            Get_Entra_ID_app_registration_secret: [
              'Succeeded'
            ]
          }
          type: 'Http'
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          keyvault: {
            connectionId: keyVaultConnection.id
            connectionName: keyVaultConnection.name
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
                identity: managedIdentity.id
              }
            }
            id: managedApi.id
          }
        }
      }
    }
  }
}

resource keyVaultConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: '${workloadName}-keyvaultconnection'
  location: location
  // `parameterValueSet`is undocumented magic. Because it is not part of the schema for Microsoft.Web/connections
  // resources, `properties` must be wrapped in `any()` to prevent Bicep from failing with a type validation error.
  properties: any({
    displayName: 'keyvault'
    api: {
      // name: 'keyvault'
      id: managedApi.id
      // type: 'Microsoft.Web/locations/managedApis'
    }
    parameterValueSet: {
      name: 'oauthMI'
      values: {
        vaultName: {
          value: keyVaultName
        }
      }
    }
  })
}

resource managedApi 'Microsoft.Web/locations/managedApis@2016-06-01' existing = {
  scope: subscription()
  name: '${location}/keyvault'
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${workloadName}-managedidentity'
  location: location
}

resource keyVaultSecretsUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource managedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, managedIdentity.id, keyVaultSecretsUserRoleDefinition.id, keyVault.id)
  scope: keyVault
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: keyVaultSecretsUserRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workloadName}-workflow-diagnosticsettings'
  scope: workflow
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

output keyVaultConnectionName string = keyVaultConnection.name
output workflowId string = workflow.id
