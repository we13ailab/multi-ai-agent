package com.javatechie.config;

import com.javatechie.agents.OrderAgent;
import com.javatechie.agents.RefundAgent;
import com.javatechie.agents.ResponseAgent;
import com.javatechie.agents.WorkflowSupportAgent;
import com.javatechie.listener.DebugAgentListener;
import com.javatechie.tool.OrderTools;
import com.javatechie.tool.RefundTool;
import dev.langchain4j.agentic.AgenticServices;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.service.tool.ToolArgumentsErrorHandler;
import dev.langchain4j.service.tool.ToolExecutionErrorHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AgentConfig {

    @Bean
    public OrderAgent orderAgent(
            ChatModel chatModel,
            OrderTools orderTools,
            ToolArgumentsErrorHandler toolArgumentsErrorHandler,
            ToolExecutionErrorHandler toolExecutionErrorHandler) {

        return AgenticServices
                .agentBuilder(OrderAgent.class)
                .chatModel(chatModel)
                .tools(orderTools)
                // Agents built via AgenticServices are not covered by the Spring Boot
                // starter, so the shared handlers from ToolErrorHandlingConfig are
                // wired explicitly here too.
                .toolArgumentsErrorHandler(toolArgumentsErrorHandler)
                .toolExecutionErrorHandler(toolExecutionErrorHandler)
                .outputKey("orderDetails")
                .build();
    }

    @Bean
    public RefundAgent refundAgent(
            ChatModel chatModel,
            RefundTool refundTool,
            ToolArgumentsErrorHandler toolArgumentsErrorHandler,
            ToolExecutionErrorHandler toolExecutionErrorHandler) {

        return AgenticServices
                .agentBuilder(RefundAgent.class)
                .chatModel(chatModel)
                .tools(refundTool)
                .toolArgumentsErrorHandler(toolArgumentsErrorHandler)
                .toolExecutionErrorHandler(toolExecutionErrorHandler)
                .outputKey("refundDecision")
                .build();
    }

    @Bean
    public ResponseAgent responseAgent(
            ChatModel chatModel) {

        return AgenticServices
                .agentBuilder(ResponseAgent.class)
                .chatModel(chatModel)
                .outputKey("finalResponse")
                .build();
    }

    @Bean
    public WorkflowSupportAgent workflowSupportAgent(OrderAgent orderAgent,
                                                     RefundAgent refundAgent,
                                                     ResponseAgent responseAgent) {
        return AgenticServices
                .sequenceBuilder(WorkflowSupportAgent.class)
                .subAgents(orderAgent, refundAgent, responseAgent)
                .outputKey("finalResponse")
                .listener(new DebugAgentListener())
                .build();

    }
}
