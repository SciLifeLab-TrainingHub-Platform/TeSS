# API Documentation

**_This document cover the the api for fetching the events(courses) from https://training.scilifelab.se/ (base url)_**

---

## Event Listing API

**GET** `/events.json`

Retrieve a list of events that can also be filtered based on various query parameters. Filters can be combined or used individually to customize results.

## Example Usage

### Request

```http
GET /events.json
Host: https://training.scilifelab.se
```

### Response

The api will return the array of events in json based on the api query.

```json
[
  {
    "id": "integer",
    "external_id": "string or null",
    "title": "string",
    "subtitle": "string or null",
    "url": "string",
    "description": "string",
    "start": "ISO 8601 datetime",
    "end": "ISO 8601 datetime",
    "sponsors": "array of objects",
    "venue": "string",
    "city": "string",
    "country": "string",
    "postcode": "string or null",
    "latitude": "float or null",
    "longitude": "float or null",
    "created_at": "ISO 8601 datetime",
    "updated_at": "ISO 8601 datetime",
    "source": "string",
    "slug": "string",
    "content_providers": "array of objects",
    "user_id": "integer",
    "learning_objectives": "String",
    "application_deadline": "datetime or null"
    "last_scraped": "ISO 8601 datetime or null",
    "scraper_record": "boolean",
    "keywords": "array of strings",
    "event_types": "array of strings",
    "target_audience": "array of strings",
    "capacity": "integer or null",
    "eligibility": "array of strings",
    "contact": "string",
    "host_institutions": "array of strings",
    "prerequisites": "string",
    "tech_requirements": "string",
    "cost_basis": "string",
    "cost_value": "float or null",
    "funding": "string or null",
    "attendee_count": "integer or null",
    "applicant_count": "integer or null",
    "trainer_count": "integer or null",
    "feedback": "string or null",
    "notes": "string or null",
    "online": "boolean",
    "scientific_topics": "array of strings",
    "operations": "array of strings",
    "nodes": "array of objects",
    "external_resources": "array of objects"
  }
]
```

### Parameters

You can filter events by using the following query parameters. The values for each parameter can be derived from the event objects in the API
response. Simply make a request without filters to get the full list of events, examine the response, and copy relevant values to use in subsequent
requests.

#### Query Parameters

- **`city`**: Filters events by the specified city.  
  Example: `city=Stockholm`

- **`content_providers`**: Filters events by the specified content provider(s). Use this if you just want only the courses or workshops from specific unit/department
  Example: `content_providers=DDLS`
  
- **`topics`**: Filters events based on topic or topics. If you want the events based on DDLS and Precision Medicine or any other matching topic from all providers then use this. 
  Example: `topics=DDLS`
            `topics%5B%5D=DDLS&topics%5B%5D=Precision+Medicine`

- **`country`**: Filters events by the specified country.  
  Example: `country=Sweden`

- **`event_types`**: Filters events by the specified type(s) of events.  
  Example: `event_types=Workshops+and+courses`

- **`include_expired`**: Includes expired events when set to `true`.  
  Example: `include_expired=true`

- **`keywords`**: Filters events by the specified keyword(s).  
  Example: `keywords=Machine+Learning`

- **`language`**: Filters events by the specified language.  
  Example: `language=en`

- **`node`**: Filters events by the specified node (organization or location).  
  Example: `node=SciLifeLab`

- **`target_audience[]`**: Filters events by the specified target audience(s). This parameter can be repeated for multiple audiences.  
  Example: `target_audience[]=PhD+Students&target_audience[]=postdocs&target_audience[]=researchers`

- **`venue`**: Filters events by the specified venue.  
  Example: `venue=Online%2C+Link%C3%B6ping+University+Hospital+Campus+(Campus+US)`

These query parameters can be combined to create more specific filters. For example:

_Example 1: Filter by City, Country, and Keyword_
The following API call filters events based on the city `Linköping`, country `Sweden`, and the keyword `Machine Learning`:

```http
https://training.scilifelab.se/events.json?city=Link%C3%B6ping&country=Sweden&keywords=Machine+Learning
```

_Example 2: Filter by Content Providers_
The following API call filters events based on the content provider `DDLS`

```http
https://training.scilifelab.se/events.json?content_providers=DDLS
```

## Event Preview API

**GET** `/events/{slug}.json`

This endpoint allows you to retrieve detailed information about a specific event using its unique slug.

## Example Usage

```http
GET /events/machine-learning-for-life-sciences.json
Host: https://training.scilifelab.se
```

### Request Parameter

- **slug**
  - Description: A unique identifier for the event, used in the URL to fetch its details.
  - Example Value: _machine-learning-for-life-sciences.json_

### Response

The api will return the events object in json.

```json
"id": "integer",
"external_id": "string or null",
"title": "string",
"subtitle": "string or null",
"url": "string",
"description": "string",
"start": "ISO 8601 datetime",
"end": "ISO 8601 datetime",
"sponsors": "array of objects",
"venue": "string",
"city": "string",
"country": "string",
"postcode": "string or null",
"latitude": "float or null",
"longitude": "float or null",
"created_at": "ISO 8601 datetime",
"updated_at": "ISO 8601 datetime",
"source": "string",
"slug": "string",
"content_providers": "array of objects",
"user_id": "integer",
"last_scraped": "ISO 8601 datetime or null",
"scraper_record": "boolean",
"keywords": "array of strings",
"event_types": "array of strings",
"target_audience": "array of strings",
"capacity": "integer or null",
"eligibility": "array of strings",
"contact": "string",
"host_institutions": "array of strings",
"prerequisites": "string",
"learning_objectives": "String",
"application_deadline": "datetime or null"
"tech_requirements": "string",
"cost_basis": "string",
"cost_value": "float or null",
"funding": "string or null",
"attendee_count": "integer or null",
"applicant_count": "integer or null",
"trainer_count": "integer or null",
"feedback": "string or null",
"notes": "string or null",
"online": "boolean",
"scientific_topics": "array of strings",
"operations": "array of strings",
"nodes": "array of objects",
"external_resources": "array of objects"
```

## Event Count API

**GET** `/events/count.json`

Retrieve the total count of events matching specific query parameters.

## Parameters

This endpoint accepts the same query parameters as the `/events` (event listing) endpoint, allowing you to count events filtered by specific criteria.

### Query Parameters

Refer to the documentation for the '/events' endpoint for the full list of query parameters,

including:

- city
- content_providers
- country
- event_types
- keywords
- language
- node
- online
- target_audience
- venue
- include_disabled
- include_expired

### Example Usage

#### Request

`GET /events/count.json?city=Linköping&keywords=computational+biology`

#### Response

The response is a JSON object providing the count of events that match the applied filters, along with a reference URL and parameters used in the request.

```json
{
  "count": 1,
  "url": "https://training.scilifelab.se/events",
  "params": {}
}
```

**Response Attributes**

- **count**
  - The total number of events matching the applied filters.
  - Example Value: 1
- **url**
  - The base URL for the events index endpoint.
  - Example Value: https://training.scilifelab.se/events
- params
  - The query parameters applied to filter the events.
  - Example Value: {} (if no filters are applied).

## Event Redirect API

### Endpoint

**GET** `/events/:id/redirect`

This endpoint redirects the client to the external URL of the specified event. It is useful when you want to quickly navigate to the original event page from your application.

## Request Parameters

- id (path parameter):
  - The unique identifier of the event for which you want to perform the redirect.

## Response

This endpoint does not return a JSON response. Instead, it issues an HTTP redirect (302) to the event's external URL.

**Example**

**GET** `/events/63/redirect`

**Behavior**

The server responds with an HTTP redirect to:
https://www.scilifelab.se/event/integrated-structural-biology-course-2024/ The client (browser or HTTP client) will be redirected automatically to the above URL.

## Content Providers API

**GET** `/content_providers.json`
Retrieve a list of content providers that can be filtered by keyword. The API returns detailed information about content providers, including their title, description, URL, and more.

## Example Usage

### Request

```http
GET /content_providers.json
Host: https://training.scilifelab.se
```

### Response

The API will return an array of content providers in JSON format. Each content provider object will include various attributes, as shown below.

#### Example Response

```json
[
  {
    "id": "integer",
    "title": "string",
    "image_url": "string or null",
    "description": "string or null",
    "url": "string",
    "created_at": "ISO 8601 datetime",
    "updated_at": "ISO 8601 datetime",
    "contact": "string"
  }
]
```

### Query Parameters

You can filter content providers by using the following query parameter:

- \*\*`keywords`: Filters content providers based on the specified keyword(s). Example: `keywords=NBIS`

### Example Filters

#### Example 1: Filter by Keyword

The following API call filters content providers by the keyword `NBIS`:

```http
https://training.scilifelab.se/content_providers.json?keywords=NBIS
```

#### Pagination

We can use `page_size` or `per_page` to get more results:

**Increase page size:** `.../content_providers.json?page_size=<page_size>` or `.../content_providers.json?per_page=<per_page>` /// default per_page is 10

**Page through results:** `.../content_providers.json?page=<page_num>`

#### Examples:

```http
/content_providers.json?page_size=50
/content_providers.json?page=2
```
