import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb'

// DynamoDB client setup
const getDynamoClient = () => {
  const region = process.env.AWS_REGION || 'us-east-1'
  const client = new DynamoDBClient({ region })
  return DynamoDBDocumentClient.from(client)
}

export default defineEventHandler(async (event) => {
  const startTime = Date.now()
  const config = useRuntimeConfig()
  
  // Get region from Lambda environment
  const region = process.env.AWS_REGION || 'unknown'
  const isPrimary = region === config.primaryRegion
  
  // Generate unique request ID
  const requestId = crypto.randomUUID()
  
  try {
    // Get or initialize counter
    const dynamo = getDynamoClient()
    const tableName = config.dynamodbTable
    
    // Atomic increment counter
    const updateResult = await dynamo.send(new UpdateCommand({
      TableName: tableName,
      Key: {
        PK: 'GLOBAL',
        SK: 'COUNTER'
      },
      UpdateExpression: 'SET #count = if_not_exists(#count, :zero) + :inc',
      ExpressionAttributeNames: {
        '#count': 'count'
      },
      ExpressionAttributeValues: {
        ':zero': 0,
        ':inc': 1
      },
      ReturnValues: 'UPDATED_NEW'
    }))
    
    const counter = updateResult.Attributes?.count || 0
    
    // Calculate latency
    const latency = Date.now() - startTime
    
    // Format current time
    const now = new Date()
    const timeFormatter = new Intl.DateTimeFormat('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: true
    })
    const dateFormatter = new Intl.DateTimeFormat('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
    
    // Region display names
    const regionNames: Record<string, string> = {
      'us-east-1': 'N. Virginia',
      'us-west-2': 'Oregon'
    }
    
    return {
      time: timeFormatter.format(now),
      date: dateFormatter.format(now),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      region: region,
      regionName: regionNames[region] || region,
      counter: counter,
      latency: latency,
      renderMode: 'server-side',
      requestId: requestId,
      isPrimary: isPrimary
    }
    
  } catch (error) {
    console.error('Dashboard API error:', error)
    
    // Return fallback data on error
    return {
      time: new Date().toLocaleTimeString(),
      date: new Date().toLocaleDateString(),
      timezone: 'unknown',
      region: region,
      regionName: 'Error',
      counter: 0,
      latency: Date.now() - startTime,
      renderMode: 'server-side (with errors)',
      requestId: requestId,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
})
