// Weather API using Open-Meteo (free, no API key required)
// https://open-meteo.com/

interface GeoLocation {
  city: string
  region: string
  country: string
  latitude: number
  longitude: number
}

// Simple IP geolocation using ipapi.co
const getLocationFromIP = async (ip: string): Promise<GeoLocation | null> => {
  try {
    // For local development, return default
    if (ip === '127.0.0.1' || ip === '::1' || ip.includes('192.168.') || ip.includes('10.')) {
      return {
        city: 'New York',
        region: 'NY',
        country: 'US',
        latitude: 40.7128,
        longitude: -74.0060
      }
    }
    
    const response = await fetch(`https://ipapi.co/${ip}/json/`)
    if (!response.ok) return null
    
    const data = await response.json()
    return {
      city: data.city || 'Unknown',
      region: data.region || '',
      country: data.country_code || '',
      latitude: data.latitude,
      longitude: data.longitude
    }
  } catch (error) {
    console.error('Geolocation error:', error)
    return null
  }
}

// Get weather from Open-Meteo
const getWeather = async (lat: number, lon: number) => {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true`
    const response = await fetch(url)
    if (!response.ok) throw new Error('Weather API error')
    
    const data = await response.json()
    return data.current_weather
  } catch (error) {
    console.error('Weather fetch error:', error)
    return null
  }
}

// Weather code to description mapping
const getWeatherDescription = (code: number): string => {
  const codes: Record<number, string> = {
    0: 'Clear sky',
    1: 'Mainly clear',
    2: 'Partly cloudy',
    3: 'Overcast',
    45: 'Foggy',
    48: 'Depositing rime fog',
    51: 'Light drizzle',
    53: 'Moderate drizzle',
    55: 'Dense drizzle',
    61: 'Slight rain',
    63: 'Moderate rain',
    65: 'Heavy rain',
    71: 'Slight snow',
    73: 'Moderate snow',
    75: 'Heavy snow',
    77: 'Snow grains',
    80: 'Slight rain showers',
    81: 'Moderate rain showers',
    82: 'Violent rain showers',
    85: 'Slight snow showers',
    86: 'Heavy snow showers',
    95: 'Thunderstorm',
    96: 'Thunderstorm with hail',
    99: 'Heavy thunderstorm with hail'
  }
  return codes[code] || 'Unknown'
}

export default defineEventHandler(async (event) => {
  try {
    // Get client IP - handle CloudFront/Lambda proxy chain
    const headers = getRequestHeaders(event)
    const forwarded = headers['x-forwarded-for']
    const realIP = headers['x-real-ip']
    
    // CloudFront sends: client, proxy1, proxy2, ...
    // We want the first non-private IP
    let clientIP = '127.0.0.1'
    if (forwarded) {
      // Take the FIRST IP in the chain (the actual client)
      const ips = forwarded.split(',').map(ip => ip.trim())
      clientIP = ips[0] || '127.0.0.1'
    } else if (realIP) {
      clientIP = realIP
    }
    
    console.log('Weather API - IP detection:', { forwarded, realIP, clientIP })
    
    // Get location
    let location = await getLocationFromIP(clientIP)
    
    // Fallback to default if geolocation fails
    if (!location) {
      console.log('Geolocation failed for IP:', clientIP, '- using default location')
      location = {
        city: 'New York',
        region: 'NY',
        country: 'US',
        latitude: 40.7128,
        longitude: -74.0060
      }
    }
    
    // Get weather
    const weather = await getWeather(location.latitude, location.longitude)
    if (!weather) {
      return {
        error: 'Could not fetch weather',
        location: `${location.city}, ${location.region}`,
        temperature: null,
        unit: 'F',
        description: 'Weather unavailable'
      }
    }
    
    // Convert Celsius to Fahrenheit
    const tempC = weather.temperature
    const tempF = Math.round((tempC * 9/5) + 32)
    
    return {
      location: `${location.city}, ${location.region}`,
      temperature: tempF,
      unit: 'F',
      description: getWeatherDescription(weather.weathercode),
      windspeed: weather.windspeed,
      raw: weather
    }
    
  } catch (error) {
    console.error('Weather API error:', error)
    return {
      error: error instanceof Error ? error.message : 'Unknown error',
      location: 'Unknown',
      temperature: null,
      unit: 'F',
      description: 'Service unavailable'
    }
  }
})
