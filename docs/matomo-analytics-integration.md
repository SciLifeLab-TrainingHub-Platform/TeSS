# Matomo Analytics Integration

This document describes how Matomo analytics tracking is integrated into Training Portal and how to configure it for different environments.

## Overview

Training Portal uses [Matomo](https://matomo.org/) for web analytics tracking. The integration is designed to:

- Respect user privacy and cookie consent
- Only track production traffic (no development/staging pollution)
- Work with Turbolinks navigation
- Be easily configurable per deployment environment

## Architecture

### Analytics Logic Flow

```
1. User visits page
2. Check: TeSS::Config.analytics_enabled?
   ├─ Environment check: DEPLOYMENT_ENV == 'live'?
   ├─ Configuration check: Matomo URL/Site ID present?
   └─ Manual override: force_analytics_enabled?
3. Check: User consented to tracking cookies?
4. If both true: Load Matomo tracking script
5. Track page views and navigation via Turbolinks events
```

### Key Components

- **Environment Detection**: Uses `DEPLOYMENT_ENV` environment variable
- **Configuration**: Matomo URL and Site ID from Rails secrets
- **Cookie Consent**: Integrated with existing TeSS cookie consent system
- **Turbolinks Compatibility**: Tracks navigation between pages

## Configuration

### Environment Variables Required

For **production** deployment, set these environment variables:

```bash
# Enable analytics tracking (REQUIRED)
DEPLOYMENT_ENV=live

# Matomo server configuration (REQUIRED)
MATOMO_URL=""
MATOMO_SITE_ID=""
```

For **non-production** deployments:

```bash
# Disable analytics tracking
DEPLOYMENT_ENV=dev        # or 'preprod' for pre-production
```

### Rails Configuration

The Matomo configuration is handled in `config/secrets.yml`:

```yaml
production:
  matomo_url: <%= ENV["MATOMO_URL"] %>
  matomo_site_id: <%= ENV["MATOMO_SITE_ID"] %>
```

### Analytics Enablement Logic

In `config/application.rb`, the `analytics_enabled` method determines when tracking is active:

```ruby
def analytics_enabled
  force_analytics_enabled || 
  (Rails.application.secrets.google_analytics_code.present? && Rails.env.production?) ||
  (Rails.application.secrets.matomo_url.present? && ENV['DEPLOYMENT_ENV'] == 'live')
end
```

### Cookie Consent Integration

Matomo only loads when:

1. Analytics are enabled (`TeSS::Config.analytics_enabled`)
2. User has consented to tracking cookies (`cookie_consent.allow_tracking?`)

The consent system offers two options:

- **"Allow necessary cookies"**: Essential cookies only, no analytics
- **"Allow all cookies"**: Includes analytics tracking

## Testing

### Local Development Testing

1. **Verify analytics are disabled**:

   ```bash
   rails console
   TeSS::Config.analytics_enabled  # Should return false
   ENV['DEPLOYMENT_ENV']           # Should be 'dev' or nil
   ```

2. **Check page source**: Search for "Matomo" - should find nothing

### Production Testing

1. **Verify analytics are enabled**:

   ```bash
   # On production server
   rails console
   TeSS::Config.analytics_enabled  # Should return true
   ENV['DEPLOYMENT_ENV']           # Should be 'live'
   ```

2. **Test tracking flow**:
   - Visit site and accept "Allow all cookies"
   - Navigate between pages
   - Check browser Network tab for requests to matomo instance url
   - Verify in Matomo dashboard: Visitors → Real-time

3. **Test cookie consent**:
   - "Allow necessary cookies" → No Matomo requests
   - "Allow all cookies" → Matomo requests visible

## Troubleshooting

### Analytics Not Working

1. **Check environment variable**:

   ```bash
   echo $DEPLOYMENT_ENV  # Should be 'live' for production
   ```

2. **Check Matomo configuration**:

   ```bash
   rails console
   Rails.application.secrets.matomo_url.present?     # Should be true
   Rails.application.secrets.matomo_site_id.present? # Should be true
   ```

3. **Check analytics enablement**:

   ```bash
   rails console
   TeSS::Config.analytics_enabled  # Should be true
   ```

### Tracking Development/Staging Traffic

If you see non-production traffic in Matomo:

- Verify `DEPLOYMENT_ENV` is set correctly on all environments
- Check that analytics are properly disabled in non-production

### Cookie Consent Issues

- Ensure cookie consent system is working properly
- Check browser console for JavaScript errors
- Verify cookie banner appears for new users

## Security and Privacy

### Data Protection

- Analytics only track users who explicitly consent
- No tracking occurs in development/staging environments
- IP addresses are handled according to Matomo configuration
- No personally identifiable information is sent to analytics

### GDPR Compliance

- Users can opt out via "Allow necessary cookies"
- Cookie preferences can be changed at any time
- Clear notice about analytics usage provided

### Updating Matomo Configuration

1. Update environment variables on production server
2. Restart Rails application
3. Verify new configuration in Rails console
4. Test tracking functionality

### Monitoring

- Monitor Matomo dashboard for data quality
- Check error logs for JavaScript errors
- Verify tracking across different user flows
- Review cookie consent acceptance rates

## External Resources

- [Matomo Documentation](https://developer.matomo.org/)
- [Matomo JavaScript Tracking API](https://developer.matomo.org/api-reference/tracking-javascript)
- [GDPR Compliance with Matomo](https://matomo.org/docs/privacy/)
