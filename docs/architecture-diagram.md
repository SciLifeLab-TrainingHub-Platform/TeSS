# TeSS Architecture Documentation

## Table of Contents
- [TeSS Architecture Documentation](#tess-architecture-documentation)
  - [Table of Contents](#table-of-contents)
  - [System Overview](#system-overview)
  - [Component Architecture](#component-architecture)
  - [System Components](#system-components)
    - [Core Application](#core-application)
      - [Rails Application](#rails-application)
    - [Data Layer](#data-layer)
      - [PostgreSQL Database](#postgresql-database)
      - [Redis](#redis)
      - [Apache Solr](#apache-solr)
    - [Background Processing](#background-processing)
      - [Sidekiq Workers](#sidekiq-workers)
    - [Authentication Flow](#authentication-flow)
    - [Data flow](#data-flow)
    - [Search Flow](#search-flow)
    - [Background Job Processing  Flow](#background-job-processing--flow)

## System Overview

TeSS (Training e-Support Service) is a Ruby on Rails application that provides a portal for discovering and registering training events and materials in the life sciences domain.

## Component Architecture
```mermaid
graph TD
    %% External Layer
    LB[Load Balancer]
    
    %% Authentication
    Auth[Authentication<br/>- Local authentication<br/>- OIDC Providers/LS-login]
    
    %% Application Core
    Rails[Rails Application<br/>- PUMA server<br/>- Port 3000<br/>- API + WebUI]
    
    %% Storage Systems
    FileStorage[File Storage for<br/>uploading user<br/>images, static<br/>assets]
    
    Redis[Redis<br/>- Sidekiq Job queue<br/>- Geocoding cache<br/>- API Token Storage<br/>- Fragment Caching]
    
    PostgreSQL[(PostgreSQL Db<br/>- Primary Database<br/>- All App Data<br/>- CRUD operations)]
    
    Solr[Apache Solr<br/>- Search Engine<br/>- Full Text Search<br/>- Faceted Browse]
    
    %% Background Processing
    Sidekiq[Sidekiq Workers<br/>- Async Processing<br/>- Background Jobs<br/>- Data Import]
    
    %% External Services
    ExternalAPIs[External APIs<br/>- Google Map API<br/>- Recaptcha]
    
    %% Connections
    LB --> Rails
    Auth --> Rails
    Rails --> FileStorage
    Rails -->|Search Index| Solr
    Rails -->|"Store user accounts & sessions<br/>CRUD events, materials, providers<br/>Read/write all application data<br/>Connection pool (database.yml)"| PostgreSQL
    Rails --> Redis
    Redis --> Sidekiq
    Sidekiq -->|Store ingested data| PostgreSQL
    Sidekiq -->|Update Search Index| Solr
    Sidekiq -->|Data Ingestion| ExternalAPIs
```

## System Components

### Core Application

#### Rails Application

The main application server built with Ruby on Rails framework, running on Puma web server.

- **Port**: 3000
- **Endpoints**: Web UI and RESTful JSON API
- **Scaling**: Supports horizontal scaling with multiple instances behind load balancer
- **Configuration**: Managed through `config/application.rb` and environment-specific settings

### Data Layer

#### PostgreSQL Database

Primary relational database system for persistent data storage.

- **Stores**: 
  - User accounts and authentication data
  - Training events and materials
  - Content provider information
  - Application sessions
- **Connection Pool**: Configured via `database.yml`

#### Redis

In-memory key-value store for high-performance operations.

- **Primary Function**: Sidekiq job queue backend
- **Secondary Functions**:
  - Geocoding results cache
  - API token storage
  - Fragment caching
- **Configuration**: Set via `REDIS_URL` environment variable

#### Apache Solr

Enterprise search platform for full-text search capabilities.

- **Features**:
  - Full-text search indexing
  - Faceted search and filtering
  - Autocomplete suggestions
- **Integration**: Sunspot Rails gem
- **Configuration**: `config/sunspot.yml`

### Background Processing

#### Sidekiq Workers

Asynchronous job processing system for background tasks.

- **Concurrency**: Configurable worker threads
- **Job Types**:
  - Data import from external sources
  - Geocoding via Nominatim API
  - Email notifications
  - Search index updates
  
- **Queue Priority**:
  1. `critical` - Time-sensitive operations
  2. `default` - Standard background jobs
  3. `mailers` - Email delivery
  4. `imports` - External data ingestion
  5. `geocoding` - Location processing

### Authentication Flow

```mermaid
sequenceDiagram
    participant User
    participant TeSS
    participant IdP as Identity Provider

    User->>TeSS: Click LS-Login
    TeSS-->>IdP: Redirect
    IdP-->>User: Login Form
    User->>IdP: Credentials
    IdP->>TeSS: User Data Callback
    Note over TeSS: Create/Update Account
    TeSS-->>User: Sign In Success
```


### Data flow

```mermaid
sequenceDiagram
    participant User
    participant Rails
    participant PostgreSQL
    participant Solr

    User->>Rails: Submit Event Form
    Rails->>Rails: Validate Data
    Rails->>PostgreSQL: Save Event
    PostgreSQL-->>Rails: Confirm Save
    Rails->>Solr: Index Event
    Solr-->>Rails: Confirm Index
    Rails-->>User: Success Response
```

### Search Flow

```mermaid
sequenceDiagram
    participant User
    participant Rails
    participant Solr
    participant PostgreSQL

    User->>Rails: Search Query
    Rails->>Solr: Query Index
    Solr-->>Rails: Return IDs & Scores
    Rails->>PostgreSQL: Fetch Full Records
    PostgreSQL-->>Rails: Return Data
    Rails->>Rails: Format Results
    Rails-->>User: Display Results
```

### Background Job Processing  Flow

```mermaid
sequenceDiagram
    participant Cron
    participant Rails
    participant Redis
    participant Sidekiq
    participant External API as External API
    participant PostgreSQL

    Cron->>Rails: Trigger Import
    Rails->>Redis: Enqueue Job
    Sidekiq->>Redis: Poll Queue
    Redis-->>Sidekiq: Return Job
    Sidekiq->>External API: Fetch Data
    External API-->>Sidekiq: Return Data
    Sidekiq->>PostgreSQL: Save Data
    Sidekiq->>Solr: Update Index
```
