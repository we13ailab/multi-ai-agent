# Multi AI Agent — LangChain4j Order & Refund Workflow Demo

<img width="1672" height="941" alt="Modern AI Agent Architecture Flowchart" src="https://github.com/user-attachments/assets/b600f1a5-3b27-4e5b-b427-e5ff60656526" />


<img width="1672" height="941" alt="LangChain4j Multi-Agent Workflow Diagram" src="https://github.com/user-attachments/assets/76d4aa68-e004-4ff0-b5e0-963300e33f54" />

A Spring Boot application that demonstrates how to build a **multi-agent AI workflow** with LangChain4j. Instead of a single chatbot, incoming refund requests are processed by a pipeline of specialised agents — `OrderAgent` → `RefundAgent` → `ResponseAgent` — each with its own prompt, tools and responsibility, composed with the LangChain4j Agentic API.

The project also exposes a plain chat agent and a tool-using order support agent, so you can compare the single-agent and multi-agent styles side by side. All agents can call structured Java tools backed by a MySQL database instead of making up answers.

## Project purpose

The application shows how to:

- compose multiple specialised agents into a sequential workflow with `AgenticServices`
- share data between agents through the agentic scope (`@V` template variables and output keys)
- attach different tools to different agents in the same workflow
- observe every agent invocation with an `AgentListener`
- integrate LangChain4j `@AiService` beans and Agentic agents in one Spring Boot app
- handle tool errors safely with curated, LLM-visible messages

## Technologies used

- Java 21
- Spring Boot 4.1.1
- Spring Web MVC
- Spring Data JPA
- MySQL Connector/J
- LangChain4j 1.21.0-beta31
- LangChain4j OpenAI Spring Boot starter
- LangChain4j Agentic API (`langchain4j-agentic`)
- GLM-5.3-Flash model via the OpenCode Go API (OpenAI-compatible endpoint)
- Maven build tool
- JUnit 5 for test setup

## Architecture overview

The system is organized around the following layers:

1. Controller layer
   - `AiSupportController`
   - Exposes endpoints under `/api/ai-support`

2. Agent layer (LangChain4j Agentic API)
   - `OrderAgent` — extracts the order ID and fetches real order details
   - `RefundAgent` — checks refund eligibility against the refund policy
   - `ResponseAgent` — composes the final customer-facing answer
   - `WorkflowSupportAgent` — the sequential composition of the three agents above
   - Assembled programmatically in `AgentConfig` via `AgenticServices`

3. AI service layer (`@AiService` beans)
   - `JavaTechieAIAgent` — general-purpose chat agent
   - `OrderSupportAIAgent` — single-agent order support with tools

4. Domain/service layer
   - `OrderService` — business rules for orders
   - `RefundService` — refund policy lookup

5. Tool layer
   - `OrderTools` — `getOrderStatus`, `cancelOrder`
   - `RefundTool` — `checkRefundEligibility`

6. Observability
   - `DebugAgentListener` — logs every agent start/end and the agentic scope

7. Persistence layer
   - `OrderRepository`, `RefundPolicyRepository`

8. Database model
   - `OrderEntity` (table `orders`), `RefundPolicy` (table `refund_policy`)

## Key application flow

When an HTTP request is sent to the workflow endpoint:

- the controller receives the customer request
- the agentic scope is created and the first agent is invoked
- `OrderAgent` extracts the order ID and calls the `getOrderStatus` tool
- the tool queries the `orders` table through `OrderService` / `OrderRepository`
- the order details are written to the scope under the `orderDetails` output key
- `RefundAgent` reads `{{orderDetails}}`, determines the order status and calls the `checkRefundEligibility` tool
- the refund decision is written to the scope under the `refundDecision` output key
- `ResponseAgent` reads the request, order details and refund decision and writes the final customer answer
- the workflow returns the `finalResponse` output to the controller

Example flow for a refund inquiry:

- Customer asks: "Can I get a refund for my order ORD-1001?"
- `OrderAgent` invokes `getOrderStatus("ORD-1001")` → real order record from MySQL
- `RefundAgent` invokes `checkRefundEligibility("Shipped")` → policy row from the `refund_policy` table
- `ResponseAgent` turns both results into a short, helpful reply — without inventing anything

Every step is logged by `DebugAgentListener` (`=== AGENT START ===` / `=== AGENT END ===`), and every tool call by SLF4J logging (`TOOL CALLED -> ...`).

## Project structure

```text
multi-ai-agent/
├── .gitignore
├── compose.yml
├── pom.xml
├── README.md
├── request.http
├── multi-ai-agent.postman_collection.json
├── src/
│   ├── main/
│   │   ├── java/com/javatechie/
│   │   │   ├── Langchain4jExampleApplication.java
│   │   │   ├── agents/
│   │   │   │   ├── OrderAgent.java
│   │   │   │   ├── RefundAgent.java
│   │   │   │   ├── ResponseAgent.java
│   │   │   │   └── WorkflowSupportAgent.java
│   │   │   ├── config/
│   │   │   │   ├── AgentConfig.java
│   │   │   │   └── ToolErrorHandlingConfig.java
│   │   │   ├── controller/
│   │   │   │   └── AiSupportController.java
│   │   │   ├── exception/
│   │   │   │   ├── OrderCannotBeCancelledException.java
│   │   │   │   ├── OrderNotFoundException.java
│   │   │   │   └── RefundPolicyNotFoundException.java
│   │   │   ├── listener/
│   │   │   │   └── DebugAgentListener.java
│   │   │   ├── model/
│   │   │   │   ├── OrderEntity.java
│   │   │   │   └── RefundPolicy.java
│   │   │   ├── repository/
│   │   │   │   ├── OrderRepository.java
│   │   │   │   └── RefundPolicyRepository.java
│   │   │   ├── service/
│   │   │   │   ├── JavaTechieAIAgent.java
│   │   │   │   ├── OrderService.java
│   │   │   │   ├── OrderSupportAIAgent.java
│   │   │   │   └── RefundService.java
│   │   │   └── tool/
│   │   │       ├── OrderTools.java
│   │   │       └── RefundTool.java
│   │   └── resources/
│   │       └── application.yaml
│   └── test/
│       └── java/com/javatechie/
│           └── Langchain4JExampleApplicationTests.java
```

The root `.gitignore` excludes generated Maven output (`target/`), IDE project metadata, logs, temporary files, and common operating-system files.

## Configuration

The project is configured in `src/main/resources/application.yaml`.

### Main settings

```yaml
spring:
  application:
    name: langchain4j-example
  datasource:
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql://localhost:3306/javatechie
    username: ${DB_USERNAME:root}
    password: ${DB_PASSWORD:Password}

  jpa:
    show-sql: true
    hibernate:
      ddl-auto: update
      naming:
        physical-strategy: org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
    properties:
      hibernate:
        dialect: org.hibernate.dialect.MySQLDialect
    defer-datasource-initialization: true

langchain4j:
  open-ai:
    chat-model:
      base-url: https://opencode.ai/inference/go/openai/v1
      api-key: ${OPENCODE_API_KEY}
      model-name: glm-5.3-flash
      custom-headers:
        User-Agent: multi-ai-agent/1.0
        x-opencode-session: multi-ai-agent-order-refund-workflow
      log-requests: true
      log-responses: true
```

### Important notes

- The project expects a MySQL database named `javatechie` on localhost.
- The app uses `ddl-auto: update`, so Hibernate can create or update tables based on the entity model.
- The LLM is served through the OpenAI-compatible OpenCode Go endpoint (`base-url` above). Set the `OPENCODE_API_KEY` environment variable before starting the application; the key is never stored in source control. Other Chat-Completions-native Go models (for example `glm-5.3`, `kimi-k3.1-pro`, `deepseek-v4.1-flash`) can be used by changing `model-name`.
- The custom `User-Agent` and `x-opencode-session` headers identify the client to the Go endpoint and enable routing and prompt-caching optimizations.
- Database credentials default to local development values and can be overridden with the `DB_USERNAME` and `DB_PASSWORD` environment variables.
- The server listens on the Spring Boot default port `8080` (no `server.port` override).

## Data model

The application uses two JPA entities.

### `OrderEntity` (table `orders`)

Entity fields:

- `id` — primary key
- `orderId` — unique order identifier (`order_id` column)
- `customerName`
- `productName`
- `status`
- `currentLocation`
- `expectedDelivery`
- `totalAmount`
- `paymentStatus`

Repository method:

```java
Optional<OrderEntity> findByOrderId(String orderId);
```

### `RefundPolicy` (table `refund_policy`)

Entity fields:

- `id` — primary key
- `orderStatus` — the order status this policy applies to
- `eligible` — whether that status is refund-eligible
- `message` — the customer-facing policy explanation

Repository method:

```java
Optional<RefundPolicy> findByOrderStatus(String orderStatus);
```

## Order and refund logic

### `OrderService`

- `getOrderStatus(String orderId)`
  - fetches order details from the repository
  - throws `OrderNotFoundException` if the order is not found
- `cancelOrder(String orderId)`
  - loads the order
  - refuses cancellation if status is `Shipped` (throws `OrderCannotBeCancelledException`)
  - changes the status to `CANCELLED`, clears `expectedDelivery` and saves the record

### `RefundService`

- `checkEligibility(String orderStatus)`
  - looks up the refund policy for the given order status
  - throws `RefundPolicyNotFoundException` if no policy row exists

All three exceptions implement LangChain4j's `ToolErrorVisibleToLlm`, so when they
escape a tool, only a curated, user-facing message is sent to the LLM instead of
raw internal error details.

### Tools

The tools are annotated with `@Tool`, which tells LangChain4j that these Java methods are callable by the AI model:

- `OrderTools.getOrderStatus(String orderId)` — used by `OrderAgent` and `OrderSupportAIAgent`
- `OrderTools.cancelOrder(String orderId)` — used by `OrderSupportAIAgent`
- `RefundTool.checkRefundEligibility(String orderStatus)` — used by `RefundAgent`

## Tool error handling

`ToolErrorHandlingConfig` declares two beans:

- `ToolArgumentsErrorHandler` — sends argument errors (invalid JSON, missing parameters) back to the LLM so it can self-correct
- `ToolExecutionErrorHandler` — lets only `ToolErrorVisibleToLlm` exceptions reach the LLM; everything else fails the invocation so bugs and infrastructure errors surface as errors instead of leaking internal details

The Spring Boot starter wires these automatically into every `@AiService` bean. Because the workflow agents are built programmatically with `AgenticServices` (not covered by the starter), `AgentConfig` passes the same handlers explicitly to `OrderAgent` and `RefundAgent`.

## Agent definitions

### Workflow agents (LangChain4j Agentic API)

`OrderAgent` — prompt template extracts the order ID from `{{request}}`, calls the order tool, returns order details (output key `orderDetails`).

`RefundAgent` — receives `{{request}}` and `{{orderDetails}}`, determines the order status, calls the refund tool, returns the decision (output key `refundDecision`).

`ResponseAgent` — receives `{{request}}`, `{{orderDetails}}` and `{{refundDecision}}`, returns the final customer answer (output key `finalResponse`).

`WorkflowSupportAgent` — the entry point assembled in `AgentConfig`:

```java
AgenticServices
        .sequenceBuilder(WorkflowSupportAgent.class)
        .subAgents(orderAgent, refundAgent, responseAgent)
        .outputKey("finalResponse")
        .listener(new DebugAgentListener())
        .build();
```

Each sub-agent writes its output into the shared agentic scope; the next agent reads it via `@V` template variables, which is how data flows through the pipeline.

### `@AiService` agents

`JavaTechieAIAgent` — general-purpose chat agent with an identity system message:

```java
@SystemMessage("""
        You are JavaTechie Assistant, a helpful and concise AI assistant.

        You are powered by the GLM model (glm-5.3-flash, trained by Z.ai),
        served through the OpenCode Go API. If asked who you are or which
        model you run on, answer truthfully based on this information.
        """)
String chat(String message);
```

Without this system message, models cannot reliably self-identify.

`OrderSupportAIAgent` — the single-agent alternative to the workflow: an ecommerce support assistant with access to the order tools, instructed never to invent order status.

## REST endpoints

### General chat endpoint

```http
GET /api/ai-support?message=hello
```

Sends a text prompt to the generic AI agent (no tools).

### Order support endpoint

```http
GET /api/ai-support/order?message=What is the status of order ORD-1001?
```

Routes the message through the single order support agent with access to order tools.

### Multi-agent workflow endpoint

```http
GET /api/ai-support/workflow?request=Can I get a refund for my order ORD-1001?
```

Runs the full `OrderAgent` → `RefundAgent` → `ResponseAgent` pipeline and returns the final response.

## Example usage

### Start the app

```bash
export OPENCODE_API_KEY=<your-opencode-go-api-key>
mvn spring-boot:run
```

### Example requests

```bash
curl "http://localhost:8080/api/ai-support?message=How%20are%20you?"
curl "http://localhost:8080/api/ai-support/order?message=What%20is%20the%20status%20of%20order%20ORD-1001?"
curl "http://localhost:8080/api/ai-support/workflow?request=Can%20I%20get%20a%20refund%20for%20my%20order%20ORD-1001%3F"
```

## Required MySQL setup

Docker Compose starts MySQL automatically when the Spring Boot application starts (Docker Compose and a running Docker daemon must be installed). The `compose.yml` service uses the same database name and credentials as `application.yaml`; the named `mysql_data` volume retains database files across container restarts and recreation.

You can also start the database manually:

```sql
CREATE DATABASE javatechie;
USE javatechie;
```

Hibernate will create the `orders` and `refund_policy` tables automatically due to `ddl-auto: update` (with `PhysicalNamingStrategyStandardImpl`, unannotated field names become column names as-is).

Sample data:

```sql
INSERT INTO orders (
    order_id, customerName, productName, status,
    currentLocation, expectedDelivery, totalAmount, paymentStatus
) VALUES
    ('ORD-1001', 'John Doe', 'iPhone 15', 'Shipped', 'Hyderabad', '2026-11-05', 999.00, 'PAID'),
    ('ORD-1002', 'Jane Smith', 'MacBook Pro', 'Processing', 'Warehouse', '2026-11-10', 2499.00, 'PAID'),
    ('ORD-1003', 'Bob Brown', 'AirPods Pro', 'Shipped', 'Bengaluru', '2026-11-03', 249.00, 'PAID');

INSERT INTO refund_policy (orderStatus, eligible, message) VALUES
    ('Shipped', false, 'Orders that have already been shipped cannot be refunded automatically. Contact support after delivery to arrange a return.'),
    ('Processing', true, 'Orders still being processed are eligible for a full refund.'),
    ('CANCELLED', true, 'Cancelled orders are refunded to the original payment method within 5 business days.'),
    ('DELIVERED', false, 'Delivered orders must be returned within 30 days to qualify for a refund.');
```

## Build and run commands

### Compile the project

```bash
mvn clean compile
```

### Run tests

```bash
mvn test
```

### Start locally

```bash
mvn spring-boot:run
```

Spring Boot's Docker Compose integration starts the MySQL service from `compose.yml` before the application and stops it when the application shuts down. To manage the database separately, use `docker compose up -d` and `docker compose down`; the named volume remains intact when containers are removed. To permanently remove stored database data, explicitly remove the volume with `docker compose down --volumes`.

## Testing

### Automated test

The repository contains a minimal Spring Boot test:

```java
@SpringBootTest
class Langchain4JExampleApplicationTests {
    @Test
    void contextLoads() {
    }
}
```

This verifies that the Spring application context loads successfully.

### Manual API testing

Two ready-made assets cover every endpoint, tool-triggering scenario and negative case:

- `request.http` — for the IntelliJ HTTP Client and VS Code REST Client
- `multi-ai-agent.postman_collection.json` — for Postman, with response assertions

Watch the app console while running them: each workflow request should produce three `=== AGENT START ===` / `=== AGENT END ===` pairs plus `TOOL CALLED -> ...` lines for the order and refund tools.

## Notes and best practices

- Keep API keys out of source control.
- Use environment variables or secret management in production.
- Real-world systems should validate user input and enforce authorization.
- For production use, add logging, circuit breakers, retries, better error handling, and request validation.
- Keep each workflow agent small and focused — one responsibility per agent keeps prompts and tools easy to reason about.
- The project is a demo and intentionally keeps the order and refund operations simple.

## Common issues

### 1. MySQL connection failure

Check:
- MySQL is running locally
- database name is `javatechie`
- username/password match your local configuration
- driver is available via Maven dependency

### 2. OpenCode Go API key missing

Set the `OPENCODE_API_KEY` environment variable (an OpenCode Go subscription key) before starting the app.

### 3. Port already in use

The app uses the Spring Boot default port `8080`. If it is occupied, add a `server.port` override in `application.yaml`:

```yaml
server.port: 8081
```

### 4. Refund tool answers "no policy defined"

The `refund_policy` table has no row for the order's status — insert one (see the sample data above). Unknown statuses throw `RefundPolicyNotFoundException`, which the agent relays as a curated message.

## References and official documentation

1. LangChain4j official documentation: https://docs.langchain4j.dev/

2. LangChain4j Spring Boot integration: https://docs.langchain4j.dev/integrations/spring-boot/

3. LangChain4j AI Services: https://docs.langchain4j.dev/tutorials/ai-services

4. LangChain4j Tools — Error Handling: https://docs.langchain4j.dev/tutorials/tools#error-handling

5. Spring Boot official docs: https://spring.io/projects/spring-boot

6. Spring Data JPA docs: https://spring.io/projects/spring-data-jpa

7. OpenCode Go (model API used by this project): https://opencode.ai/v2/docs/console/go/

8. OpenAI API documentation (for the fallback OpenAI configuration): https://platform.openai.com/docs/api-reference

9. MySQL official docs: https://dev.mysql.com/doc/

10. Maven official website: https://maven.apache.org/

11. Java 21 documentation: https://docs.oracle.com/en/java/javase/21/

12. JPA/Hibernate reference: https://hibernate.org/orm/

## Summary

This project demonstrates a multi-agent order-and-refund workflow built with the LangChain4j Agentic API, Spring Boot and MySQL. It shows how specialised agents with separate tools and prompts can be composed into a pipeline, observed end-to-end, and protected by curated tool error handling — a useful starting point for building production-grade workflow automation and customer support systems.
