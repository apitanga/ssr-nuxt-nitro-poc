import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb'

const getDynamoClient = () => {
  const region = process.env.AWS_REGION || 'us-east-1'
  const client = new DynamoDBClient({ region })
  return DynamoDBDocumentClient.from(client)
}

export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  
  try {
    const dynamo = getDynamoClient()
    const tableName = config.dynamodbTable
    
    // Atomic increment
    const result = await dynamo.send(new UpdateCommand({
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
    
    return {
      success: true,
      counter: result.Attributes?.count || 0
    }
    
  } catch (error) {
    console.error('Counter API error:', error)
    throw createError({
      statusCode: 500,
      statusMessage: 'Failed to increment counter'
    })
  }
})
