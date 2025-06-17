---
id: microservices
title: Microservices Architecture Design
tags: [microservices, architecture, distributed-systems, containers]
category: architecture
---

Help me design and implement a microservices architecture for my application.

**Current Monolith (if applicable):**
```
[Describe your current monolithic application]
```

**Business Requirements:**
- **Domain Complexity:** [Number of business domains/bounded contexts]
- **Team Structure:** [Number of teams and their sizes]
- **Deployment Frequency:** [How often do you need to deploy?]
- **Scalability Needs:** [Which parts need independent scaling?]

**Microservices Goals:**
- [ ] Independent deployability
- [ ] Technology diversity
- [ ] Team autonomy
- [ ] Fault isolation
- [ ] Scalability
- [ ] Performance optimization
- [ ] Data sovereignty
- [ ] Organizational alignment

**Technical Requirements:**
- **Communication Patterns:** [Sync/async, REST/GraphQL/messaging]
- **Data Management:** [Database per service, shared databases]
- **Infrastructure:** [Kubernetes, Docker, service mesh]
- **Monitoring:** [Distributed tracing, metrics, logging]

**Service Boundaries:**
[Describe potential service boundaries based on business domains]

**Current Challenges:**
- [ ] Monolith deployment bottlenecks
- [ ] Technology constraints
- [ ] Team dependencies
- [ ] Performance issues
- [ ] Scaling difficulties
- [ ] Database contention

**Migration Strategy:**
- [ ] Strangler Fig pattern
- [ ] Database decomposition
- [ ] Big Bang migration
- [ ] Incremental extraction

Please help me:
1. **Identify service boundaries** using domain-driven design principles
2. **Design service communication** patterns and API contracts
3. **Plan data decomposition** strategy for databases
4. **Set up service discovery** and configuration management
5. **Implement distributed monitoring** and observability
6. **Design deployment pipeline** for multiple services
7. **Address cross-cutting concerns** like security and logging
8. **Create migration roadmap** from monolith to microservices