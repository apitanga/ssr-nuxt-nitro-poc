// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  devtools: { enabled: true },
  
  // Nitro configuration for AWS Lambda
  nitro: {
    preset: 'aws-lambda',
    // Additional lambda-specific config
    awsLambda: {
      // Use streaming for larger responses
      streaming: false
    }
  },

  // Runtime config (environment variables)
  runtimeConfig: {
    // Private keys (server-only)
    dynamodbTable: process.env.DYNAMODB_TABLE || 'ssr-poc-visits',
    primaryRegion: process.env.PRIMARY_REGION || 'us-east-1',
    drRegion: process.env.DR_REGION || 'us-west-2',
    
    // Public keys (exposed to client)
    public: {
      appName: 'SSR Server Clock',
      apiBase: '/api'
    }
  },

  // Global CSS
  css: ['~/assets/css/main.css'],

  // App head config
  app: {
    head: {
      title: 'SSR Server Clock',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: 'Multi-region SSR demo with Nuxt/Nitro on AWS Lambda' }
      ]
    }
  }
})
