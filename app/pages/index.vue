<template>
  <div>
    <header class="header">
      <h1>🌍 SSR Server Clock</h1>
      <p>Server-side rendered with Nuxt/Nitro on AWS Lambda</p>
    </header>

    <div class="dashboard">
      <!-- Server Time Card -->
      <div class="card">
        <div class="card-header">
          <span>⏰</span>
          Server Time
        </div>
        <div class="card-value">{{ serverTime }}</div>
        <div class="card-subtext">
          {{ serverDate }}<br>
          Timezone: {{ timezone }}
        </div>
      </div>

      <!-- Region Card -->
      <div class="card">
        <div class="card-header">
          <span>🌎</span>
          Serving Region
        </div>
        <div class="card-value">
          <span class="region-badge" :class="regionClass">
            <span class="status-dot status-online"></span>
            {{ region }}
          </span>
        </div>
        <div class="card-subtext">
          {{ regionName }}<br>
          Latency: ~{{ latency }}ms
        </div>
      </div>

      <!-- Weather Card -->
      <div class="card">
        <div class="card-header">
          <span>🌡️</span>
          Weather
        </div>
        <div v-if="weather" class="weather-content">
          <div class="weather-icon">{{ weatherIcon }}</div>
          <div class="temperature">{{ weather.temperature }}°{{ weather.unit }}</div>
          <div class="card-subtext">
            {{ weather.description }}<br>
            {{ weather.location }}
          </div>
        </div>
        <div v-else class="loading">
          <div class="spinner"></div>
        </div>
      </div>

      <!-- Visit Counter Card -->
      <div class="card">
        <div class="card-header">
          <span>👥</span>
          Visit Count
        </div>
        <div class="card-value">{{ formatNumber(counter) }}</div>
        <div class="card-subtext">
          Total visits across all regions<br>
          Updates in real-time
        </div>
      </div>
    </div>

    <!-- Admin Section -->
    <div class="admin-section">
      <h2>🧪 Testing & Diagnostics</h2>
      <p>Current rendering mode: <strong>{{ renderMode }}</strong></p>
      <p>Request ID: <code>{{ requestId }}</code></p>
      <br>
      <button 
        class="button button-danger" 
        @click="testFailover"
        :disabled="loading"
      >
        {{ loading ? 'Testing...' : 'Test Failover' }}
      </button>
      <p v-if="failoverResult" class="card-subtext" style="margin-top: 1rem;">
        {{ failoverResult }}
      </p>
    </div>
  </div>
</template>

<script setup>
// This page is server-side rendered
const { data: pageData } = await useFetch('/api/dashboard', {
  key: 'dashboard-data',
  server: true
})

// Client-side weather fetch (needs IP)
const { data: weather } = await useFetch('/api/weather', {
  server: false // Fetch on client to get accurate IP
})

// Computed values from server data
const serverTime = computed(() => pageData.value?.time || '---')
const serverDate = computed(() => pageData.value?.date || '---')
const timezone = computed(() => pageData.value?.timezone || '---')
const region = computed(() => pageData.value?.region || 'unknown')
const regionName = computed(() => pageData.value?.regionName || 'Unknown Region')
const counter = computed(() => pageData.value?.counter || 0)
const latency = computed(() => pageData.value?.latency || 0)
const renderMode = computed(() => pageData.value?.renderMode || 'unknown')
const requestId = computed(() => pageData.value?.requestId || '---')

// Region styling
const regionClass = computed(() => {
  return region.value.includes('east') ? 'region-primary' : 'region-dr'
})

// Weather icon mapping
const weatherIcon = computed(() => {
  if (!weather.value) return '🌡️'
  const desc = weather.value.description?.toLowerCase() || ''
  if (desc.includes('clear') || desc.includes('sun')) return '☀️'
  if (desc.includes('cloud')) return '☁️'
  if (desc.includes('rain')) return '🌧️'
  if (desc.includes('snow')) return '❄️'
  if (desc.includes('thunder')) return '⛈️'
  return '🌡️'
})

// Number formatting
const formatNumber = (num) => {
  return new Intl.NumberFormat().format(num)
}

// Failover testing
const loading = ref(false)
const failoverResult = ref('')

const testFailover = async () => {
  loading.value = true
  failoverResult.value = 'Testing...'
  
  try {
    // Make request to test routing
    const start = performance.now()
    const response = await fetch('/api/health')
    const duration = Math.round(performance.now() - start)
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    const data = await response.json()
    failoverResult.value = `✅ Health check passed! Served by ${data.region} in ${duration}ms`
  } catch (error) {
    console.error('Failover test error:', error)
    failoverResult.value = `❌ Error: ${error instanceof Error ? error.message : 'Unknown error'}`
  } finally {
    loading.value = false
  }
}
</script>
