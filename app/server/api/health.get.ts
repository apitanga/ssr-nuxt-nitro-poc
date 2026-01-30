export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const region = process.env.AWS_REGION || 'unknown'
  
  // Simple health check endpoint
  // Used by Route53 health checks and CloudWatch
  
  return {
    status: 'healthy',
    region: region,
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  }
})
