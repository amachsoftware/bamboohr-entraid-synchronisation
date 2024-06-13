@description('Workload name')
param workloadName string

@description('Logic Apps workflow ID')
param workflowId string

resource actionGroup 'microsoft.insights/actionGroups@2023-09-01-preview' = {
  name: '${workloadName}-actiongroup'
  location: 'Global'
  properties: {
    groupShortName: 'bamboohrsync'
    enabled: true
    emailReceivers: [
      {
        name: 'Slack'
        emailAddress: 'team-internal-technol-aaaajzjqlqh7b6vvbiwblqikva@amach.slack.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

resource metricAlert 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: '${workloadName}-metricalert'
  location: 'global'
  properties: {
    severity: 1
    enabled: true
    scopes: [workflowId]
    evaluationFrequency: 'PT5M'
    windowSize: 'P1D'
    criteria: {
      allOf: [
        {
          threshold: 1
          name: 'GreaterThanOrEqualOne'
          metricNamespace: 'Microsoft.Logic/workflows'
          metricName: 'RunFailurePercentage'
          operator: 'GreaterThanOrEqual'
          timeAggregation: 'Maximum'
          skipMetricValidation: false
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Logic/workflows'
    targetResourceRegion: 'northeurope'
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
