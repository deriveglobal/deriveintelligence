import { getSlice, setState, mergeState } from './store.js';
import { renderEditParticipantModal } from './components/participants.js';

const DEFAULT_FRAMEWORK_NAME = "Fleet & Service Operations Framework v1";
const DEFAULT_FRAMEWORK_VERSION = "v1";
const DEFAULT_FRAMEWORK_INDUSTRY = "Fleet & Service Operations";

const stakeholderArchitecture = [
  {
    scope: "Internal Stakeholders",
    groups: [
      { family: "Executive", roles: ["Owner", "CEO", "Managing Director"] },
      { family: "Leadership", roles: ["General Manager", "COO", "Operations Director"] },
      { family: "Operations", roles: ["Branch Manager", "Service Manager", "Dispatch Manager"] },
      { family: "Customer Service", roles: ["Dispatcher", "Customer Service Rep"] },
      { family: "Technical", roles: ["Technician", "Field Service Technician", "Inspector"] },
      { family: "Supply Chain", roles: ["Warehouse Manager", "Inventory Coordinator", "Logistics Coordinator"] },
      { family: "Commercial", roles: ["Sales Manager", "Sales Representative", "Account Manager"] },
      { family: "Finance", roles: ["Finance Manager", "Accountant"] },
      { family: "Technology", roles: ["IT Manager", "Systems Administrator"] },
      { family: "Workforce", roles: ["HR / Workforce Manager"] }
    ]
  },
  {
    scope: "External Stakeholders",
    groups: [
      { family: "Customers", roles: ["Fleet Customer", "Dealer Customer", "Retail Customer"] },
      { family: "Partners", roles: ["Service Partner", "Dealer Partner", "Supplier"] }
    ]
  }
];

const stakeholderLayers = stakeholderArchitecture.map((scope) => ({
  layer: scope.scope,
  people: scope.groups.flatMap((group) => group.roles)
}));

const stakeholderRoleAliases = {
  owner: "owner",
  ceo: "owner",
  "managing-director": "owner",
  executive: "owner",
  "general-manager": "general-manager",
  gm: "general-manager",
  coo: "general-manager",
  "operations-director": "operations-manager",
  operations: "operations-manager",
  "operations-manager": "operations-manager",
  "branch-manager": "branch-managers",
  "branch-managers": "branch-managers",
  "service-manager": "operations-manager",
  "dispatch-manager": "dispatcher",
  dispatcher: "dispatcher",
  dispatch: "dispatcher",
  "customer-service": "customer-service",
  "customer-service-rep": "customer-service",
  technician: "technician",
  technicians: "technician",
  "field-service-technician": "technician",
  inspector: "technician",
  warehouse: "warehouse",
  "warehouse-manager": "warehouse",
  "inventory-coordinator": "warehouse",
  "logistics-coordinator": "warehouse",
  finance: "finance-manager",
  "finance-manager": "finance-manager",
  accountant: "finance-manager",
  sales: "sales-manager",
  "sales-manager": "sales-manager",
  "sales-representative": "sales-manager",
  "account-manager": "sales-manager",
  "it-manager": "it-manager",
  "systems-administrator": "it-manager",
  "hr-manager": "hr-manager",
  "hr-workforce-manager": "hr-manager",
  "workforce-manager": "hr-manager",
  customer: "fleet-customers",
  "fleet-customer": "fleet-customers",
  "fleet-customers": "fleet-customers",
  "dealer-customer": "fleet-customers",
  "retail-customer": "fleet-customers",
  partner: "service-partners",
  "service-partner": "service-partners",
  "service-partners": "service-partners",
  "dealer-partner": "service-partners",
  supplier: "supplier"
};

const discoveryFramework = [
  {
    code: "A",
    title: "Business Strategy",
    signals: ["Goals", "Growth", "Competition", "Risks"]
  },
  {
    code: "B",
    title: "Processes",
    signals: ["How work gets done", "Bottlenecks", "Delays", "Approvals"]
  },
  {
    code: "C",
    title: "Data",
    signals: ["Creation", "Storage", "Sharing", "Quality"]
  },
  {
    code: "D",
    title: "Technology",
    signals: ["Systems", "Integrations", "Shadow tools"]
  },
  {
    code: "E",
    title: "People",
    signals: ["Skills", "Training", "Adoption", "Resistance"]
  },
  {
    code: "F",
    title: "Customers",
    signals: ["Expectations", "Frustrations", "Loyalty"]
  },
  {
    code: "G",
    title: "Financial Impact",
    signals: ["Costs", "Waste", "Revenue leakage"]
  },
  {
    code: "H",
    title: "Innovation",
    signals: ["New opportunities", "Future capabilities"]
  }
];

const surveyFields = [
  "Question ID",
  "Stakeholder Type",
  "Category",
  "Question Type",
  "Required",
  "Scoring Eligible",
  "Weight",
  "Question Text"
];

const questionTypes = ["Single Choice", "Multiple Choice", "Likert Scale (1-5)", "Numeric", "Open Text", "Yes/No"];

const businessDomainsTaxonomy = [
  {
    id: "strategy",
    name: "Strategy",
    description: "Business direction, growth objectives, competitive positioning, and long-term planning.",
    subdomains: ["Vision", "Strategic Planning", "Business Goals", "Growth Strategy", "Market Expansion", "Competitive Positioning"]
  },
  {
    id: "governance",
    name: "Governance",
    description: "Decision-making structure, accountability, policies, and management oversight.",
    subdomains: ["Decision Making", "Organizational Structure", "Policies", "Management Controls", "Accountability", "Performance Reviews"]
  },
  {
    id: "sales",
    name: "Sales",
    description: "Revenue generation through customer acquisition and account management.",
    subdomains: ["Lead Management", "Opportunity Management", "Quoting", "Pricing", "Customer Acquisition", "Account Management", "Sales Performance"]
  },
  {
    id: "marketing",
    name: "Marketing",
    description: "Brand visibility, lead generation, and customer engagement.",
    subdomains: ["Brand Management", "Digital Marketing", "Campaign Management", "Lead Generation", "Customer Engagement", "Market Research"]
  },
  {
    id: "customer_experience",
    name: "Customer Experience",
    description: "Customer satisfaction, retention, service quality, and loyalty.",
    subdomains: ["Customer Satisfaction", "Customer Retention", "Complaint Management", "Service Quality", "Customer Communication", "Customer Journey"]
  },
  {
    id: "service_delivery",
    name: "Service Delivery",
    description: "Execution of customer services from request to completion.",
    subdomains: ["Work Orders", "Scheduling", "Dispatch", "Service Execution", "Quality Control", "Service Completion"]
  },
  {
    id: "field_operations",
    name: "Field Operations",
    description: "Activities performed outside company facilities.",
    subdomains: ["Mobile Workforce", "Roadside Assistance", "On-Site Service", "Field Inspections", "Technician Productivity", "Field Reporting"]
  },
  {
    id: "fleet_operations",
    name: "Fleet Operations",
    description: "Management of fleet-related services and assets.",
    subdomains: ["Fleet Tire Management", "Fleet Maintenance", "Contract Services", "Fleet Reporting", "Tire Lifecycle Management", "Fleet Performance"]
  },
  {
    id: "branch_operations",
    name: "Branch Operations",
    description: "Management and performance of branch locations.",
    subdomains: ["Branch Performance", "Operational Consistency", "Resource Allocation", "Local Management", "Branch Reporting", "Service Capacity"]
  },
  {
    id: "inventory_management",
    name: "Inventory Management",
    description: "Inventory visibility, stock control, and inventory accuracy.",
    subdomains: ["Stock Levels", "Inventory Accuracy", "Inventory Visibility", "Stock Replenishment", "Inventory Planning", "Cycle Counts"]
  },
  {
    id: "procurement",
    name: "Procurement",
    description: "Purchasing and supplier management activities.",
    subdomains: ["Purchasing", "Supplier Management", "Vendor Performance", "Purchase Approvals", "Contract Management", "Cost Control"]
  },
  {
    id: "logistics",
    name: "Logistics",
    description: "Movement and distribution of products and materials.",
    subdomains: ["Transportation", "Distribution", "Route Planning", "Warehouse Transfers", "Delivery Performance", "Logistics Costs"]
  },
  {
    id: "warehouse_operations",
    name: "Warehouse Operations",
    description: "Storage and handling of inventory and materials.",
    subdomains: ["Receiving", "Putaway", "Picking", "Packing", "Storage", "Warehouse Productivity"]
  },
  {
    id: "manufacturing",
    name: "Manufacturing",
    description: "Production and manufacturing activities.",
    subdomains: ["Production Planning", "Capacity Management", "Quality Control", "Production Efficiency", "Manufacturing Costs", "Production Reporting"]
  },
  {
    id: "retreading_operations",
    name: "Retreading Operations",
    description: "Retread production and casing management.",
    subdomains: ["Casing Inspection", "Retread Production", "Retread Quality", "Production Scheduling", "Retread Profitability", "Retread Reporting"]
  },
  {
    id: "finance",
    name: "Finance",
    description: "Financial management and reporting.",
    subdomains: ["Billing", "Accounts Receivable", "Accounts Payable", "Cash Flow", "Budgeting", "Financial Reporting"]
  },
  {
    id: "profitability",
    name: "Profitability",
    description: "Measurement and management of business profitability.",
    subdomains: ["Customer Profitability", "Product Profitability", "Service Profitability", "Margin Analysis", "Cost Analysis", "Revenue Analysis"]
  },
  {
    id: "data_management",
    name: "Data Management",
    description: "Collection, quality, ownership, and accessibility of data.",
    subdomains: ["Data Quality", "Data Ownership", "Master Data", "Data Accessibility", "Data Governance", "Single Source of Truth"]
  },
  {
    id: "reporting_analytics",
    name: "Reporting & Analytics",
    description: "Business reporting, KPIs, dashboards, and analytics.",
    subdomains: ["KPIs", "Dashboards", "Business Intelligence", "Management Reporting", "Performance Analytics", "Forecasting"]
  },
  {
    id: "technology",
    name: "Technology",
    description: "Systems, applications, infrastructure, and integrations.",
    subdomains: ["ERP", "CRM", "Infrastructure", "System Integration", "Application Management", "Technology Support"]
  },
  {
    id: "automation",
    name: "Automation",
    description: "Workflow automation and reduction of manual effort.",
    subdomains: ["Workflow Automation", "Process Automation", "Document Automation", "Reporting Automation", "Approval Automation", "AI Enablement"]
  },
  {
    id: "workforce",
    name: "Workforce",
    description: "Employee productivity, staffing, and workforce management.",
    subdomains: ["Staffing", "Productivity", "Training", "Performance Management", "Workload Management", "Employee Engagement"]
  },
  {
    id: "change_management",
    name: "Change Management",
    description: "Organizational readiness and adoption of change.",
    subdomains: ["Transformation Readiness", "User Adoption", "Communication", "Resistance Management", "Training Programs", "Stakeholder Alignment"]
  },
  {
    id: "compliance",
    name: "Compliance",
    description: "Regulatory, legal, and operational compliance.",
    subdomains: ["Regulations", "Audits", "Safety", "Documentation", "Industry Standards", "Policy Compliance"]
  },
  {
    id: "risk_management",
    name: "Risk Management",
    description: "Identification and mitigation of business risks.",
    subdomains: ["Operational Risk", "Financial Risk", "Customer Risk", "Supplier Risk", "Technology Risk", "Business Continuity"]
  },
  {
    id: "innovation",
    name: "Innovation",
    description: "New business models, technologies, and growth opportunities.",
    subdomains: ["New Services", "New Products", "Digital Innovation", "AI Opportunities", "Competitive Innovation", "Future Capabilities"]
  }
];

const assessmentCategoriesTaxonomy = [
  {
    id: "process",
    name: "Process",
    description: "Issues or opportunities related to workflows, steps, approvals, handoffs, delays, rework, standardization, and execution."
  },
  {
    id: "data",
    name: "Data",
    description: "Issues or opportunities related to data quality, missing data, duplicate data, accessibility, ownership, accuracy, and single source of truth."
  },
  {
    id: "technology",
    name: "Technology",
    description: "Issues or opportunities related to software systems, ERP, CRM, integrations, infrastructure, usability, system gaps, and technical limitations."
  },
  {
    id: "people",
    name: "People",
    description: "Issues or opportunities related to employees, skills, training, workload, communication, accountability, productivity, and adoption."
  },
  {
    id: "customer",
    name: "Customer",
    description: "Issues or opportunities related to customer experience, satisfaction, communication, service visibility, response time, complaints, and retention."
  },
  {
    id: "financial",
    name: "Financial",
    description: "Issues or opportunities related to revenue, cost, margin, billing, profitability, waste, cash flow, and financial visibility."
  },
  {
    id: "risk",
    name: "Risk",
    description: "Issues or opportunities related to operational risk, customer risk, supplier risk, financial risk, technology risk, and business continuity."
  },
  {
    id: "compliance",
    name: "Compliance",
    description: "Issues or opportunities related to regulations, documentation, audits, safety, legal requirements, and industry standards."
  },
  {
    id: "automation",
    name: "Automation",
    description: "Issues or opportunities related to reducing manual work through workflow automation, AI, integrations, digital forms, approvals, and reporting automation."
  },
  {
    id: "governance",
    name: "Governance",
    description: "Issues or opportunities related to decision-making, ownership, policies, accountability, management control, and organizational structure."
  },
  {
    id: "reporting",
    name: "Reporting",
    description: "Issues or opportunities related to KPIs, dashboards, management reports, performance tracking, analytics, and visibility."
  },
  {
    id: "communication",
    name: "Communication",
    description: "Issues or opportunities related to internal communication, customer communication, information handoffs, WhatsApp dependency, email dependency, and coordination gaps."
  }
];

const problemTypesTaxonomy = [
  {
    group: "Process Problems",
    items: [
      { id: "bottleneck", name: "Bottleneck" },
      { id: "manual_process", name: "Manual Process" },
      { id: "duplicate_activity", name: "Duplicate Activity" },
      { id: "rework", name: "Rework" },
      { id: "approval_delay", name: "Approval Delay" },
      { id: "process_complexity", name: "Process Complexity" },
      { id: "lack_of_standardization", name: "Lack of Standardization" },
      { id: "process_gap", name: "Process Gap" },
      { id: "unclear_ownership", name: "Unclear Ownership" },
      { id: "capacity_constraint", name: "Capacity Constraint" }
    ]
  },
  {
    group: "Data Problems",
    items: [
      { id: "missing_data", name: "Missing Data" },
      { id: "inaccurate_data", name: "Inaccurate Data" },
      { id: "duplicate_data", name: "Duplicate Data" },
      { id: "data_silo", name: "Data Silo" },
      { id: "data_access_issue", name: "Data Access Issue" },
      { id: "poor_data_quality", name: "Poor Data Quality" },
      { id: "reporting_gap", name: "Reporting Gap" },
      { id: "no_single_source_of_truth", name: "No Single Source Of Truth" }
    ]
  },
  {
    group: "Technology Problems",
    items: [
      { id: "legacy_system", name: "Legacy System" },
      { id: "missing_integration", name: "Missing Integration" },
      { id: "poor_usability", name: "Poor Usability" },
      { id: "system_performance_issue", name: "System Performance Issue" },
      { id: "system_downtime", name: "System Downtime" },
      { id: "spreadsheet_dependency", name: "Spreadsheet Dependency" },
      { id: "whatsapp_dependency", name: "WhatsApp Dependency" },
      { id: "email_dependency", name: "Email Dependency" },
      { id: "paper_based_process", name: "Paper-Based Process" },
      { id: "lack_of_automation", name: "Lack Of Automation" }
    ]
  },
  {
    group: "People Problems",
    items: [
      { id: "training_gap", name: "Training Gap" },
      { id: "skill_gap", name: "Skill Gap" },
      { id: "resource_shortage", name: "Resource Shortage" },
      { id: "knowledge_dependency", name: "Knowledge Dependency" },
      { id: "communication_breakdown", name: "Communication Breakdown" },
      { id: "poor_adoption", name: "Poor Adoption" },
      { id: "change_resistance", name: "Change Resistance" },
      { id: "workload_imbalance", name: "Workload Imbalance" }
    ]
  },
  {
    group: "Customer Problems",
    items: [
      { id: "slow_response_time", name: "Slow Response Time" },
      { id: "poor_service_visibility", name: "Poor Service Visibility" },
      { id: "customer_complaints", name: "Customer Complaints" },
      { id: "service_quality_issue", name: "Service Quality Issue" },
      { id: "customer_churn_risk", name: "Customer Churn Risk" },
      { id: "poor_customer_experience", name: "Poor Customer Experience" }
    ]
  },
  {
    group: "Financial Problems",
    items: [
      { id: "revenue_leakage", name: "Revenue Leakage" },
      { id: "cost_overrun", name: "Cost Overrun" },
      { id: "billing_delay", name: "Billing Delay" },
      { id: "inventory_waste", name: "Inventory Waste" },
      { id: "margin_erosion", name: "Margin Erosion" },
      { id: "cashflow_issue", name: "Cashflow Issue" }
    ]
  },
  {
    group: "Risk Problems",
    items: [
      { id: "operational_risk", name: "Operational Risk" },
      { id: "supplier_risk", name: "Supplier Risk" },
      { id: "customer_risk", name: "Customer Risk" },
      { id: "technology_risk", name: "Technology Risk" },
      { id: "compliance_risk", name: "Compliance Risk" },
      { id: "business_continuity_risk", name: "Business Continuity Risk" }
    ]
  }
];

const impactModel = {
  dimensions: [
    {
      id: "time_impact",
      name: "Time Impact",
      description: "Amount of time lost due to the issue.",
      scale: { 1: "Negligible", 2: "Low", 3: "Moderate", 4: "High", 5: "Critical" }
    },
    {
      id: "cost_impact",
      name: "Cost Impact",
      description: "Direct or indirect cost impact.",
      scale: { 1: "Negligible", 2: "Low", 3: "Moderate", 4: "High", 5: "Critical" }
    },
    {
      id: "customer_impact",
      name: "Customer Impact",
      description: "Impact on customer satisfaction, retention, and experience.",
      scale: { 1: "Negligible", 2: "Low", 3: "Moderate", 4: "High", 5: "Critical" }
    },
    {
      id: "revenue_impact",
      name: "Revenue Impact",
      description: "Potential effect on sales, renewals, contracts, and growth.",
      scale: { 1: "Negligible", 2: "Low", 3: "Moderate", 4: "High", 5: "Critical" }
    },
    {
      id: "risk_impact",
      name: "Risk Impact",
      description: "Exposure to operational, compliance, financial, or technology risks.",
      scale: { 1: "Negligible", 2: "Low", 3: "Moderate", 4: "High", 5: "Critical" }
    },
    {
      id: "employee_impact",
      name: "Employee Impact",
      description: "Effect on productivity, morale, workload, and retention.",
      scale: { 1: "Negligible", 2: "Low", 3: "Moderate", 4: "High", 5: "Critical" }
    }
  ]
};

const scoringModel = {
  frequency: { 1: "Rare", 2: "Monthly", 3: "Weekly", 4: "Daily", 5: "Continuous" },
  severity: { 1: "Minor", 2: "Low", 3: "Moderate", 4: "High", 5: "Critical" },
  automationPotential: { 1: "No Automation Opportunity", 2: "Low", 3: "Medium", 4: "High", 5: "Very High" },
  priorityWeights: {
    severity: 0.3,
    frequency: 0.2,
    customer_impact: 0.15,
    revenue_impact: 0.15,
    cost_impact: 0.1,
    risk_impact: 0.1
  },
  classificationBands: [
    { min: 90, max: 100, label: "Critical" },
    { min: 75, max: 89, label: "High" },
    { min: 50, max: 74, label: "Medium" },
    { min: 25, max: 49, label: "Low" },
    { min: 0, max: 24, label: "Minor" }
  ],
  findingOutputFields: [
    "problem",
    "domain",
    "category",
    "problem_type",
    "severity",
    "frequency",
    "time_impact",
    "cost_impact",
    "customer_impact",
    "revenue_impact",
    "risk_impact",
    "employee_impact",
    "automation_potential",
    "priority_score",
    "recommendation",
    "roadmap_phase"
  ]
};

const recommendationEngine = {
  types: [
    {
      id: "quick_win",
      name: "Quick Win",
      timeline: "0-3 Months",
      description: "Low effort, high value improvements."
    },
    {
      id: "improvement_project",
      name: "Improvement Project",
      timeline: "3-6 Months",
      description: "Moderate effort operational improvements."
    },
    {
      id: "digital_initiative",
      name: "Digital Initiative",
      timeline: "6-12 Months",
      description: "Technology-enabled business improvements."
    },
    {
      id: "strategic_transformation",
      name: "Strategic Transformation",
      timeline: "12+ Months",
      description: "Organization-wide transformation initiatives."
    }
  ],
  categories: [
    "Process Improvement",
    "Workflow Standardization",
    "Automation",
    "System Integration",
    "Data Governance",
    "Reporting & Analytics",
    "Customer Experience",
    "Inventory Optimization",
    "Workforce Productivity",
    "Training",
    "Technology Modernization",
    "AI Enablement",
    "Risk Reduction",
    "Cost Reduction",
    "Revenue Growth"
  ],
  mappingRules: [
    {
      problemTypes: ["Manual Process", "Duplicate Activity", "Spreadsheet Dependency"],
      recommendation: "Implement Digital Workflow Automation",
      category: "Automation",
      effort: "Medium",
      expectedBenefit: "Reduce administrative effort and eliminate duplicate entry"
    },
    {
      problemTypes: ["Missing Integration", "Data Silo"],
      recommendation: "Integrate ERP, CRM and Operational Systems",
      category: "System Integration",
      effort: "High",
      expectedBenefit: "Create single source of truth"
    },
    {
      problemTypes: ["Reporting Gap", "Poor Data Quality"],
      recommendation: "Create KPI Dashboard & Reporting Layer",
      category: "Reporting & Analytics",
      effort: "Medium",
      expectedBenefit: "Improve management visibility"
    }
  ],
  scoring: {
    effortScore: { 1: "Very Low", 2: "Low", 3: "Medium", 4: "High", 5: "Very High" },
    businessValueScore: { 1: "Very Low", 2: "Low", 3: "Medium", 4: "High", 5: "Very High" },
    implementationRiskScore: { 1: "Very Low", 2: "Low", 3: "Medium", 4: "High", 5: "Very High" }
  },
  opportunityMatrix: [
    {
      zone: "Quick Wins",
      rule: "High Value + Low Effort",
      examples: ["Digital forms", "Automated reports", "Approval notifications"]
    },
    {
      zone: "Major Projects",
      rule: "High Value + Medium Effort",
      examples: ["Customer portal", "Inventory visibility platform", "Mobile technician app"]
    },
    {
      zone: "Strategic Programs",
      rule: "High Value + High Effort",
      examples: ["Fleet intelligence platform", "Enterprise ERP modernization", "AI predictive maintenance"]
    }
  ],
  outputFields: [
    "recommendation_id",
    "title",
    "business_domain",
    "problem_types",
    "recommendation_category",
    "recommendation_type",
    "description",
    "expected_benefit",
    "effort_score",
    "business_value_score",
    "implementation_risk_score",
    "estimated_timeline",
    "priority_score",
    "roadmap_phase"
  ],
  krbExample: {
    title: "Emergency Dispatch Management Platform",
    business_domain: "field_operations",
    problem_types: ["manual_process", "whatsapp_dependency", "communication_breakdown"],
    recommendation_category: "Automation",
    recommendation_type: "Digital Initiative",
    expected_benefit: "Reduce dispatch time, improve visibility, improve SLA compliance",
    effort_score: 3,
    business_value_score: 5,
    implementation_risk_score: 2,
    estimated_timeline: "4 Months",
    priority_score: 95,
    roadmap_phase: "Phase 1"
  }
};

const roadmapGenerator = {
  phases: [
    {
      id: "phase_1",
      name: "Quick Wins",
      timeline: "0-3 Months",
      objective: "Generate momentum and visible results quickly."
    },
    {
      id: "phase_2",
      name: "Foundation",
      timeline: "3-9 Months",
      objective: "Build core capabilities and remove major constraints."
    },
    {
      id: "phase_3",
      name: "Optimization",
      timeline: "9-18 Months",
      objective: "Improve efficiency, visibility and performance."
    },
    {
      id: "phase_4",
      name: "Transformation",
      timeline: "18+ Months",
      objective: "Create long-term competitive advantage."
    }
  ],
  placementRules: [
    {
      phase: "Phase 1 - Quick Wins",
      criteria: "Low effort, medium to high business value, low implementation risk.",
      examples: ["Digital forms", "Automated reports", "KPI dashboards", "Approval notifications", "Standardized templates"]
    },
    {
      phase: "Phase 2 - Foundation",
      criteria: "Medium effort and high business value.",
      examples: ["Inventory visibility", "Service request management", "Customer portal foundation", "Branch performance reporting"]
    },
    {
      phase: "Phase 3 - Optimization",
      criteria: "Efficiency, visibility, and performance improvements after foundation capabilities exist.",
      examples: ["Route optimization", "Workforce productivity tracking", "Predictive inventory planning", "Advanced analytics"]
    },
    {
      phase: "Phase 4 - Transformation",
      criteria: "Enterprise-wide, long-term competitive advantage initiatives.",
      examples: ["AI-powered forecasting", "Predictive maintenance", "Fleet intelligence platform", "Enterprise-wide process orchestration"]
    }
  ],
  dependencyRule: {
    initiative: "AI Fleet Insights",
    dependsOn: ["Fleet Data Collection", "Customer Portal", "Service Tracking"]
  },
  themes: [
    "Customer Experience",
    "Operational Excellence",
    "Inventory Optimization",
    "Data & Reporting",
    "Automation",
    "Workforce Productivity",
    "Technology Modernization",
    "AI & Innovation"
  ],
  outputFields: [
    "id",
    "title",
    "theme",
    "phase",
    "business_domain",
    "description",
    "expected_outcomes",
    "dependencies",
    "estimated_effort",
    "business_value",
    "priority_score",
    "estimated_timeline"
  ],
  krbRoadmap: [
    {
      phase: "Phase 1 - Quick Wins",
      groups: [
        { theme: "Data & Reporting", items: ["Standardized service reporting", "Branch KPI dashboard", "Automated weekly management reports"] },
        { theme: "Workforce Productivity", items: ["Digital technician forms", "Mobile photo documentation"] }
      ]
    },
    {
      phase: "Phase 2 - Foundation",
      groups: [
        { theme: "Service Operations", items: ["Central dispatch platform", "Service request tracking", "SLA monitoring"] },
        { theme: "Inventory", items: ["Multi-location inventory visibility", "Inventory movement tracking"] }
      ]
    },
    {
      phase: "Phase 3 - Optimization",
      groups: [
        { theme: "Fleet Operations", items: ["Tire lifecycle tracking", "Fleet customer reporting", "Performance analytics"] }
      ]
    },
    {
      phase: "Phase 4 - Transformation",
      groups: [
        { theme: "AI & Innovation", items: ["Predictive tire replacement", "Failure prediction", "Fleet intelligence platform", "AI-driven service planning"] }
      ]
    }
  ],
  portfolioSummary: {
    quickWins: 12,
    foundationProjects: 8,
    optimizationProjects: 5,
    transformationProjects: 3,
    estimatedTotalValue: "To be calculated from recommendation business value scores",
    estimatedTotalEffort: "To be calculated from effort scores and timelines",
    highestPriorityInitiatives: []
  },
  executiveOutput: [
    "Top 5 Quick Wins",
    "Top 5 High-Impact Projects",
    "Top 5 Strategic Initiatives",
    "Major Risks",
    "Recommended Roadmap",
    "Expected Business Outcomes"
  ],
  expectedBusinessOutcomes: [
    "Reduce dispatch time by 60%",
    "Improve inventory accuracy by 20%",
    "Reduce reporting effort by 80%",
    "Increase service visibility for customers",
    "Improve technician productivity"
  ]
};

const executiveIntelligence = {
  components: [
    "Maturity Scoring",
    "Industry Benchmarking",
    "Strength Analysis",
    "Weakness Analysis",
    "Opportunity Analysis",
    "Risk Analysis",
    "ROI Forecasting",
    "Executive Summary"
  ],
  maturityDimensions: ["Leadership", "Strategy", "Operations", "Customer Experience", "Data", "Technology", "Automation", "Analytics", "Innovation"],
  maturityScale: { 1: "Ad Hoc", 2: "Emerging", 3: "Defined", 4: "Managed", 5: "Optimized" },
  maturityExample: {
    Leadership: 4.2,
    Operations: 2.8,
    Data: 2.1,
    Technology: 2.7,
    Automation: 1.9
  },
  benchmarkProfile: {
    industry: "Tire Industry",
    size: "50-250 employees",
    complexity: ["Multi-location", "Fleet focused", "Mobile workforce"]
  },
  benchmarkResult: {
    inventory_management: { company_score: 58, industry_average: 73 },
    customer_experience: { company_score: 72, industry_average: 65 }
  },
  strengths: [
    {
      title: "Strong Fleet Customer Relationships",
      evidence: ["High customer retention", "Strong contract base"]
    }
  ],
  weaknesses: [
    {
      title: "High Dependency on Manual Communication",
      evidence: ["WhatsApp dependency", "Phone-based dispatch"]
    }
  ],
  opportunities: [
    {
      title: "Dispatch Automation",
      estimatedValue: "High",
      timeframe: "6 Months"
    }
  ],
  risks: [
    {
      title: "Knowledge Dependency",
      severity: "High",
      impact: "Operational Continuity"
    }
  ],
  roiExample: {
    initiative: "Automated Reporting",
    currentState: { hoursPerWeek: 22 },
    futureState: { hoursPerWeek: 3 },
    estimatedSavings: { annualHours: 988 }
  },
  executiveNarrative: ["Current State", "Key Findings", "Major Risks", "Major Opportunities", "Recommended Roadmap", "Expected Outcomes"],
  scorecard: {
    overallMaturity: 61,
    strengthCount: 12,
    criticalIssues: 7,
    quickWins: 11,
    majorProjects: 6,
    strategicInitiatives: 3,
    estimatedAnnualValue: ""
  },
  krbOutput: {
    strengths: ["Strong fleet relationships", "Retreading expertise", "National service capabilities"],
    weaknesses: ["Dispatch process fragmentation", "Manual reporting", "Inventory visibility gaps"],
    topOpportunities: ["Dispatch Platform", "Fleet Customer Portal", "Tire Lifecycle Tracking", "Branch Performance Dashboard"],
    estimatedOutcomes: ["40% faster service coordination", "25% reduction in manual reporting", "Improved fleet customer retention", "Better inventory utilization"]
  },
  deliverables: ["Business Health Score", "Digital Maturity Score", "Benchmark Position", "Top 10 Risks", "Top 10 Opportunities", "Expected ROI", "Transformation Roadmap", "Executive Summary"]
};

const continuousImprovementEngine = {
  mission: ["Progress", "Results", "Maturity Growth", "Initiative Success", "Emerging Risks", "New Opportunities"],
  framework: ["Progress Tracking", "KPI Monitoring", "Initiative Tracking", "Quarterly Reassessment", "Maturity Evolution", "Opportunity Detection", "Executive Alerts"],
  initiativeExample: {
    title: "Dispatch Automation",
    status: "In Progress",
    owner: "Operations Director",
    startDate: "",
    targetDate: "",
    completionPercentage: 65
  },
  initiativeStatus: ["Not Started", "Planned", "In Progress", "Blocked", "Completed", "Cancelled"],
  kpiExample: {
    name: "Dispatch Time",
    before: 95,
    after: 28,
    unit: "minutes",
    improvement: 70.5
  },
  kpiCategories: ["Operations", "Customer Experience", "Inventory", "Finance", "Workforce", "Technology", "Automation"],
  maturityTracking: ["Leadership", "Operations", "Customer Experience", "Data", "Technology", "Automation", "Analytics"],
  maturityEvolutionExample: [
    { domain: "Data", q1: 2.1, q2: 2.8 },
    { domain: "Automation", q1: 1.9, q2: 2.7 },
    { domain: "Reporting", q1: 2.5, q2: 3.4 }
  ],
  pulseSurveys: [
    { audience: "Employees", questions: ["Has communication improved?", "Are systems easier to use?", "What new frustrations exist?"] },
    { audience: "Managers", questions: ["Which initiatives delivered value?", "What remains unresolved?"] },
    { audience: "Customers", questions: ["Has service improved?", "What still needs attention?"] }
  ],
  opportunityDetection: {
    title: "Inventory Forecasting",
    reason: "Stockouts increasing across branches",
    priority: "High"
  },
  executiveAlerts: [
    { type: "Risk Alert", message: "Inventory accuracy dropped below target." },
    { type: "Opportunity Alert", message: "Reporting automation could save an additional 400 hours annually." },
    { type: "Initiative Alert", message: "Customer Portal project delayed by 45 days." }
  ],
  benchmarkTrend: {
    customer_experience: {
      current: 78,
      previous: 64,
      industry_average: 72
    }
  },
  businessHealthScore: {
    overallScore: 74,
    trend: "+8",
    status: "Improving"
  },
  ownerDashboard: ["Current Health Score", "Maturity Trend", "Top Risks", "Top Opportunities", "Initiative Progress", "KPI Progress", "ROI Delivered"],
  commercialModel: [
    { product: "Assessment", revenueModel: "One-time fee" },
    { product: "Improvement Program", revenueModel: "Monthly subscription" }
  ],
  subscriptionIncludes: ["Quarterly pulse surveys", "KPI monitoring", "AI recommendations", "Benchmark updates", "Executive reports"],
  finalArchitecture: [
    "Layer 1 Organization Profile",
    "Layer 2 Stakeholders",
    "Layer 3 Business Domains",
    "Layer 4 Assessment Categories",
    "Layer 5 Problem Types",
    "Layer 6 Impact Model",
    "Layer 7 Recommendation Engine",
    "Layer 8 Roadmap Generator",
    "Layer 9 Executive Intelligence & Benchmarking",
    "Layer 10 Continuous Improvement Engine"
  ],
  operatingSystemCapabilities: [
    "Diagnose businesses",
    "Prioritize improvements",
    "Build roadmaps",
    "Track execution",
    "Measure results",
    "Continuously identify new opportunities"
  ]
};

const questionFramework = {
  schema: {
    id: "string",
    stakeholder_group: "string",
    stakeholder_role: "string",
    business_domain: "string",
    subdomain: "string",
    assessment_category: "string",
    problem_types_detectable: ["string"],
    impact_dimensions: ["string"],
    maturity_dimensions: ["string"],
    question_text: "string",
    question_type: "single_choice | multiple_choice | open_text | numeric | scale_1_5 | yes_no | percentage | time_duration",
    options: ["string"],
    required: true,
    scoring_enabled: true,
    weight: 1,
    follow_up_enabled: true,
    follow_up_questions: ["string"],
    kpi_outputs: ["string"],
    ai_analysis_purpose: "string",
    evidence_expected: "string",
    recommendation_triggers: ["string"],
    roadmap_relevance: "quick_win | foundation | optimization | transformation | unknown"
  },
  meanings: [
    "Who is answering?",
    "What business area does this question belong to?",
    "What problem can this question reveal?",
    "Can the answer be scored?",
    "What KPI can be extracted?",
    "What recommendation can this answer trigger?",
    "Where could it fit in the roadmap?"
  ],
  buildOrder: [
    { phase: "Phase 1", stakeholder: "Owner", targetQuestions: 60 },
    { phase: "Phase 2", stakeholder: "Operations Manager", targetQuestions: 80 },
    { phase: "Phase 3", stakeholder: "Dispatcher", targetQuestions: 70 },
    { phase: "Phase 4", stakeholder: "Branch Managers", targetQuestions: 60 },
    { phase: "Phase 5", stakeholder: "Technicians", targetQuestions: 60 },
    { phase: "Phase 6", stakeholder: "Warehouse", targetQuestions: 50 },
    { phase: "Phase 7", stakeholder: "Finance", targetQuestions: 50 },
    { phase: "Phase 8", stakeholder: "Sales", targetQuestions: 50 },
    { phase: "Phase 9", stakeholder: "Customer", targetQuestions: 30 }
  ],
  metricFirstRule: [
    "What happened?",
    "How often does it occur?",
    "How much time does it waste?",
    "How severe is the impact?",
    "Who else is affected?",
    "What KPI can prove it?"
  ],
  exampleQuestion: {
    id: "DSP-001",
    stakeholder_group: "Operations",
    stakeholder_role: "Dispatcher",
    business_domain: "service_delivery",
    subdomain: "Dispatch",
    assessment_category: "process",
    problem_types_detectable: ["manual_process", "bottleneck", "communication_breakdown", "missing_data"],
    impact_dimensions: ["time_impact", "customer_impact", "employee_impact"],
    maturity_dimensions: ["Operations", "Automation", "Customer Experience"],
    question_text: "How do service requests usually arrive?",
    question_type: "multiple_choice",
    options: ["Phone", "WhatsApp", "Email", "ERP/System", "Customer Portal", "In person", "Other"],
    required: true,
    scoring_enabled: true,
    weight: 4,
    follow_up_enabled: true,
    follow_up_questions: [
      "Which channel creates the most delays?",
      "Which channel creates the most missing information?",
      "Which channel creates the most customer complaints?"
    ],
    kpi_outputs: ["request_channel_distribution", "manual_intake_dependency", "digital_request_ratio"],
    ai_analysis_purpose: "Identify how service requests enter the business and whether intake is fragmented or manual.",
    evidence_expected: "Channel usage percentages, examples of request intake problems, screenshots or forms if available.",
    recommendation_triggers: ["customer_portal", "centralized_request_intake", "dispatch_workflow_automation"],
    roadmap_relevance: "foundation"
  }
};

const answerInterpretationModel = {
  purpose: [
    "Findings",
    "Evidence",
    "Severity",
    "Frequency",
    "Confidence",
    "Business Impact",
    "Recommendations",
    "Roadmap Initiatives"
  ],
  transformationFlow: [
    "Employee Response",
    "Finding",
    "Evidence",
    "Impact",
    "Recommendation",
    "Roadmap",
    "Executive Intelligence"
  ],
  findingObject: {
    id: "",
    title: "",
    description: "",
    stakeholder: "",
    business_domain: "",
    assessment_category: "",
    problem_types: [],
    source_question_id: "",
    source_response_id: ""
  },
  findingExample: {
    response: "We receive requests through WhatsApp and enter them into ERP manually.",
    title: "Duplicate Data Entry",
    problem_types: ["duplicate_activity", "whatsapp_dependency", "manual_process"]
  },
  evidenceObject: {
    id: "",
    finding_id: "",
    evidence_type: "",
    source: "",
    description: ""
  },
  evidenceTypes: ["Survey Response", "Interview Response", "Observation", "Document Review", "System Analysis", "KPI Measurement", "Customer Feedback"],
  confidenceScale: { 1: "Weak Evidence", 2: "Limited Evidence", 3: "Moderate Evidence", 4: "Strong Evidence", 5: "Very Strong Evidence" },
  frequencyScale: scoringModel.frequency,
  severityScale: scoringModel.severity,
  stakeholderAgreementScale: { 1: "Single Stakeholder", 2: "Limited Agreement", 3: "Moderate Agreement", 4: "High Agreement", 5: "Organization-Wide Agreement" },
  stakeholderAgreementExample: {
    issue: "Reporting is slow",
    stakeholders: ["Owner", "Operations", "Finance"],
    stakeholder_agreement: "High"
  },
  contradictionExample: {
    contradiction_detected: true,
    contradiction_type: "Data Quality",
    perceptions: ["Owner: Reporting is excellent.", "Operations: We don't trust the reports."]
  },
  aggregationExample: {
    finding: "Communication Fragmentation",
    evidence_count: 12,
    signals: ["WhatsApp dependency", "Manual communication", "Missing integrations"]
  },
  impactExample: {
    time_impact: 4,
    cost_impact: 2,
    customer_impact: 3,
    revenue_impact: 2,
    risk_impact: 1,
    employee_impact: 5
  },
  recommendationEligibilityExample: {
    finding: "Manual Reporting",
    recommendation_eligible: true,
    automation_potential: 5
  },
  outputObject: {
    id: "",
    title: "",
    business_domain: "",
    assessment_category: "",
    problem_types: [],
    frequency: 0,
    severity: 0,
    confidence: 0,
    stakeholder_agreement: 0,
    contradiction_detected: false,
    evidence_count: 0,
    time_impact: 0,
    cost_impact: 0,
    customer_impact: 0,
    revenue_impact: 0,
    risk_impact: 0,
    employee_impact: 0,
    automation_potential: 0
  },
  successCriteria: [
    "Transform raw responses into structured findings",
    "Transform structured findings into recommendations",
    "Feed roadmaps, executive reports, benchmarks, and continuous improvement tracking"
  ]
};

const kpiBusinessObjectives = [
  "Revenue Growth",
  "Profitability Improvement",
  "Customer Experience",
  "Operational Efficiency",
  "Workforce Productivity",
  "Data Visibility",
  "Risk Reduction",
  "Automation",
  "Innovation",
  "Sustainability"
];

const kpiMeasurementStatuses = {
  measured: "The company already tracks this KPI or can provide exact data.",
  estimatable: "The KPI is not formally tracked, but surveys, interviews, or available records can produce a useful estimate.",
  missing: "The KPI is important for the business model, but current data cannot measure or estimate it reliably.",
  not_applicable: "The KPI is not relevant based on the company profile."
};

const kpiDefinitionSchema = {
  id: "",
  name: "",
  business_objective: "",
  business_domain: "",
  industry: "universal | tire_industry",
  business_activity: "",
  description: "",
  formula: "",
  unit: "",
  importance_score: 1,
  measurement_difficulty: 1,
  measurement_status: "measured | estimatable | missing | not_applicable",
  required_data_points: [],
  possible_data_sources: [],
  estimation_questions: [],
  related_stakeholders: [],
  related_problem_types: [],
  question_triggers: [],
  recommendation_triggers: [],
  roadmap_relevance: "quick_win | foundation | optimization | transformation",
  benchmark_available: false
};

const kpiFormulaLibrary = {
  revenue_growth_rate: { formula: "((Current period revenue - Previous period revenue) / Previous period revenue) x 100", unit: "%" },
  new_customer_count: { formula: "Count of new customers acquired during the period", unit: "count" },
  customer_retention_rate: { formula: "(Customers retained / Customers at start of period) x 100", unit: "%" },
  customer_churn_rate: { formula: "(Customers lost during period / Customers at start of period) x 100", unit: "%" },
  average_revenue_per_customer: { formula: "Total revenue / Active customers", unit: "currency" },
  gross_margin: { formula: "((Revenue - Cost of goods sold) / Revenue) x 100", unit: "%" },
  net_profit_margin: { formula: "(Net profit / Revenue) x 100", unit: "%" },
  cost_per_service: { formula: "Total service cost / Completed services", unit: "currency/service" },
  customer_profitability: { formula: "Customer revenue - Direct and allocated customer costs", unit: "currency" },
  service_profitability: { formula: "Service revenue - Service delivery cost", unit: "currency" },
  customer_satisfaction_score: { formula: "Average customer satisfaction rating", unit: "score" },
  complaint_rate: { formula: "(Complaints / Completed services or orders) x 100", unit: "%" },
  complaint_resolution_time: { formula: "Average time between complaint creation and closure", unit: "time" },
  response_time: { formula: "Average time between request received and first response", unit: "time" },
  process_cycle_time: { formula: "Average time from process start to process completion", unit: "time" },
  first_time_resolution_rate: { formula: "(Issues resolved without repeat visit or rework / Total issues) x 100", unit: "%" },
  rework_rate: { formula: "(Rework items / Total completed work items) x 100", unit: "%" },
  manual_process_ratio: { formula: "(Manual process steps / Total process steps) x 100", unit: "%" },
  approval_cycle_time: { formula: "Average time between approval request and approval decision", unit: "time" },
  tasks_completed_per_employee: { formula: "Completed tasks / Employees involved", unit: "tasks/employee" },
  hours_lost_to_manual_work: { formula: "Estimated manual hours spent on repeatable non-value-added work", unit: "hours" },
  employee_workload_balance: { formula: "Workload variance across comparable employee groups", unit: "score" },
  training_completion_rate: { formula: "(Employees completing required training / Required employees) x 100", unit: "%" },
  system_adoption_rate: { formula: "(Active system users / Expected users) x 100", unit: "%" },
  report_preparation_time: { formula: "Average time required to prepare recurring reports", unit: "hours" },
  data_accuracy_rate: { formula: "(Accurate records / Total sampled records) x 100", unit: "%" },
  duplicate_data_entry_rate: { formula: "(Records entered more than once / Total records) x 100", unit: "%" },
  kpi_availability_score: { formula: "(Available critical KPIs / Required critical KPIs) x 100", unit: "%" },
  single_source_of_truth_score: { formula: "(Critical data entities with an authoritative source / Critical data entities) x 100", unit: "%" },
  critical_process_dependency_count: { formula: "Count of critical processes dependent on one person, system, or informal workaround", unit: "count" },
  compliance_issue_count: { formula: "Count of compliance issues identified during period", unit: "count" },
  system_downtime: { formula: "Total unavailable system time during period", unit: "hours" },
  supplier_risk_score: { formula: "Weighted score of supplier reliability, dependency, quality, and continuity risk", unit: "score" },
  operational_risk_score: { formula: "Weighted score of operational disruption probability and impact", unit: "score" },
  automation_rate: { formula: "(Automated tasks / Total repeatable tasks) x 100", unit: "%" },
  manual_task_count: { formula: "Count of repeatable tasks performed manually", unit: "count" },
  workflow_automation_coverage: { formula: "(Automated workflows / Target workflows) x 100", unit: "%" },
  reporting_automation_rate: { formula: "(Automated recurring reports / Total recurring reports) x 100", unit: "%" },
  digital_form_usage_rate: { formula: "(Digital form submissions / Total form submissions) x 100", unit: "%" },
  inventory_accuracy: { formula: "(Accurate inventory records / Total sampled inventory records) x 100", unit: "%" },
  stockout_rate: { formula: "(Stockout events / Demand events) x 100", unit: "%" },
  inventory_turnover: { formula: "Cost of goods sold / Average inventory value", unit: "turns" },
  delivery_lead_time: { formula: "Average time from order confirmation to delivery completion", unit: "time" },
  order_fulfillment_rate: { formula: "(Orders fulfilled complete and on time / Total orders) x 100", unit: "%" },
  slow_moving_inventory_ratio: { formula: "(Slow-moving inventory value / Total inventory value) x 100", unit: "%" },
  average_dispatch_time: { formula: "Average time between request creation and technician assignment", unit: "time" },
  technician_utilization_rate: { formula: "(Productive service time / Available technician time) x 100", unit: "%" },
  jobs_completed_per_technician: { formula: "Completed jobs / Active technicians", unit: "jobs/technician" },
  travel_time_per_job: { formula: "Total technician travel time / Completed jobs", unit: "time/job" },
  service_completion_time: { formula: "Average time from job start to job completion", unit: "time" },
  emergency_response_time: { formula: "Average time from emergency request creation to technician arrival", unit: "time" },
  sla_compliance_rate: { formula: "(Jobs completed within SLA / SLA-covered jobs) x 100", unit: "%" },
  average_time_to_assignment: { formula: "Average time from request creation to assignment", unit: "time" },
  average_time_to_arrival: { formula: "Average time from assignment to arrival", unit: "time" },
  emergency_job_completion_time: { formula: "Average time from emergency request creation to job completion", unit: "time" },
  customer_downtime: { formula: "Average customer vehicle or asset downtime caused by service event", unit: "time" },
  tire_cost_per_kilometer: { formula: "Total tire cost / Fleet kilometers driven", unit: "currency/km" },
  tire_failure_rate: { formula: "(Tire failures / Tires in service) x 100", unit: "%" },
  fleet_service_response_time: { formula: "Average response time for fleet service requests", unit: "time" },
  fleet_contract_renewal_rate: { formula: "(Renewed fleet contracts / Expiring fleet contracts) x 100", unit: "%" },
  preventive_service_completion_rate: { formula: "(Preventive services completed on schedule / Planned preventive services) x 100", unit: "%" },
  tire_lifecycle_visibility_score: { formula: "(Tires with complete lifecycle records / Tires under management) x 100", unit: "%" },
  casing_acceptance_rate: { formula: "(Casings accepted for retread / Casings inspected) x 100", unit: "%" },
  retread_yield_rate: { formula: "(Successful retreads / Casings entering production) x 100", unit: "%" },
  retread_success_rate: { formula: "(Retreads passing final quality / Completed retreads) x 100", unit: "%" },
  retread_production_cycle_time: { formula: "Average time from casing acceptance to finished retread", unit: "time" },
  retread_quality_issue_rate: { formula: "(Retread quality issues / Completed retreads) x 100", unit: "%" },
  retread_profitability: { formula: "Retread revenue - Retread production and casing costs", unit: "currency" },
  picking_accuracy: { formula: "(Correct picks / Total picks) x 100", unit: "%" },
  receiving_accuracy: { formula: "(Correct receiving records / Total receiving records) x 100", unit: "%" },
  warehouse_productivity: { formula: "Warehouse transactions completed / Labor hours", unit: "transactions/hour" },
  stock_transfer_time: { formula: "Average time from transfer request to receiving confirmation", unit: "time" },
  inventory_reconciliation_time: { formula: "Average time required to reconcile inventory differences", unit: "time" },
  warehouse_space_utilization: { formula: "(Used warehouse capacity / Available warehouse capacity) x 100", unit: "%" }
};

function kpiId(name) {
  return String(name)
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function inferKpiDomain(objective, activity = "") {
  if (activity.includes("warehouse") || activity.includes("distribution")) return "inventory_management";
  if (activity.includes("mobile") || activity.includes("roadside")) return "field_operations";
  if (activity.includes("fleet")) return "fleet_operations";
  if (activity.includes("retreading")) return "retreading_operations";
  const domainByObjective = {
    "Revenue Growth": "sales",
    "Profitability Improvement": "profitability",
    "Customer Experience": "customer_experience",
    "Operational Efficiency": "service_delivery",
    "Workforce Productivity": "workforce",
    "Data Visibility": "reporting_analytics",
    "Risk Reduction": "risk_management",
    Automation: "automation",
    Innovation: "innovation",
    Sustainability: "innovation"
  };
  return domainByObjective[objective] || "reporting_analytics";
}

function inferKpiDataPoints(id, name) {
  const overrides = {
    average_dispatch_time: ["Request Created Timestamp", "Technician Assigned Timestamp"],
    emergency_response_time: ["Emergency Request Created Timestamp", "Technician Arrival Timestamp"],
    average_time_to_assignment: ["Request Created Timestamp", "Assignment Timestamp"],
    average_time_to_arrival: ["Assignment Timestamp", "Arrival Timestamp"],
    emergency_job_completion_time: ["Request Created Timestamp", "Completion Timestamp"],
    customer_downtime: ["Vehicle Out-of-Service Timestamp", "Vehicle Back-in-Service Timestamp"],
    inventory_accuracy: ["System Stock Quantity", "Physical Count Quantity"],
    stockout_rate: ["Demand Event", "Available Stock Quantity", "Stockout Flag"],
    inventory_turnover: ["Cost of Goods Sold", "Average Inventory Value"],
    tire_cost_per_kilometer: ["Tire Cost", "Fleet Kilometers"],
    tire_lifecycle_visibility_score: ["Tire Asset ID", "Installation Record", "Inspection Record", "Service History", "End-of-Life Record"],
    retread_profitability: ["Retread Revenue", "Casing Cost", "Production Cost"],
    report_preparation_time: ["Report Start Time", "Report Completion Time", "Report Owner"]
  };
  if (overrides[id]) return overrides[id];
  if (/rate|margin|score|ratio|accuracy|compliance|utilization|coverage/i.test(name)) return ["Numerator", "Denominator", "Measurement Period"];
  if (/time|lead|cycle|duration|downtime/i.test(name)) return ["Start Timestamp", "End Timestamp", "Measurement Period"];
  if (/cost|profitability|revenue|margin/i.test(name)) return ["Revenue", "Cost", "Measurement Period"];
  return ["KPI Event Count", "Measurement Period", "Responsible Owner"];
}

function inferKpiSources(domain, activity = "") {
  if (domain === "inventory_management") return ["ERP", "Warehouse Management System", "Inventory counts", "Branch stock records"];
  if (domain === "field_operations") return ["Dispatch logs", "Mobile service app", "Technician reports", "Customer service records"];
  if (domain === "fleet_operations") return ["Fleet contracts", "Service history", "Tire inspection records", "Customer reports"];
  if (domain === "retreading_operations") return ["Retread production system", "Casing inspection records", "Quality control records"];
  if (domain === "profitability") return ["Accounting system", "ERP", "Service costing records", "Customer contract records"];
  if (domain === "customer_experience") return ["CRM", "Customer surveys", "Complaint records", "Call center logs"];
  if (activity) return ["ERP", "Operational records", "Survey responses", "Interview estimates"];
  return ["ERP", "CRM", "Spreadsheets", "Survey responses", "Interview estimates"];
}

function inferKpiStakeholders(domain, activity = "") {
  if (domain === "inventory_management") return ["Operations Manager", "Warehouse Manager", "Inventory Coordinator", "Branch Manager"];
  if (domain === "field_operations") return ["Operations Manager", "Dispatcher", "Technician", "Customer Service Rep"];
  if (domain === "fleet_operations") return ["Operations Manager", "Sales Manager", "Account Manager", "Fleet Customer"];
  if (domain === "retreading_operations") return ["Operations Manager", "Inspector", "Warehouse Manager", "Finance Manager"];
  if (domain === "profitability") return ["Owner", "General Manager", "Finance Manager", "Sales Manager"];
  if (domain === "customer_experience") return ["Customer Service Rep", "Sales Manager", "Account Manager", "Fleet Customer"];
  return ["Owner", "General Manager", "Operations Manager", "Finance Manager"];
}

function inferKpiProblems(id, name, objective) {
  const problems = new Set();
  if (/report|kpi|data|source|accuracy/i.test(name)) {
    problems.add("reporting_gap");
    problems.add("poor_data_quality");
  }
  if (/manual|automation|form|workflow/i.test(name) || objective === "Automation") {
    problems.add("manual_process");
    problems.add("lack_of_automation");
  }
  if (/time|cycle|dispatch|arrival|response|lead|approval/i.test(name)) {
    problems.add("delay");
    problems.add("bottleneck");
  }
  if (/inventory|stock|warehouse|picking|receiving/i.test(name)) {
    problems.add("missing_data");
    problems.add("inventory_waste");
  }
  if (/customer|complaint|sla|retention|churn/i.test(name)) {
    problems.add("poor_customer_experience");
    problems.add("customer_churn_risk");
  }
  if (/cost|profit|margin|revenue/i.test(name)) {
    problems.add("revenue_leakage");
    problems.add("cost_overrun");
  }
  if (!problems.size) problems.add("reporting_gap");
  return [...problems];
}

function buildKpiDefinition({ name, objective, industry = "universal", activity = "", description = "", importance = 4, difficulty = 3, benchmark = false, roadmap = "foundation" }) {
  const id = kpiId(name);
  const businessDomain = inferKpiDomain(objective, activity);
  const formula = kpiFormulaLibrary[id] || { formula: `${name} measured consistently over the selected period`, unit: "value" };
  const requiredDataPoints = inferKpiDataPoints(id, name);
  return {
    id,
    name,
    business_objective: objective,
    business_domain: businessDomain,
    industry,
    business_activity: activity,
    description: description || `${name} is a business vital sign used to evaluate ${objective.toLowerCase()}.`,
    formula: formula.formula,
    unit: formula.unit,
    importance_score: importance,
    measurement_difficulty: difficulty,
    measurement_status: "missing",
    required_data_points: requiredDataPoints,
    possible_data_sources: inferKpiSources(businessDomain, activity),
    estimation_questions: [
      `Do you currently track ${name}?`,
      `Where is ${name} tracked today?`,
      `Can you provide the current value for ${name}?`,
      `If not tracked, can the team estimate ${name} from recent work?`,
      `Which data points are missing to measure ${name} reliably?`
    ],
    related_stakeholders: inferKpiStakeholders(businessDomain, activity),
    related_problem_types: inferKpiProblems(id, name, objective),
    question_triggers: [
      `Ask stakeholders how ${name} is currently measured.`,
      `Ask which system or person owns the data for ${name}.`,
      `Ask whether ${requiredDataPoints.slice(0, 2).join(" and ")} are captured.`
    ],
    recommendation_triggers: [
      `If ${name} is missing, create a KPI data capture recommendation.`,
      `If ${name} is estimatable only, formalize the data source and ownership.`
    ],
    roadmap_relevance: roadmap,
    benchmark_available: benchmark
  };
}

const universalKpiGroups = [
  { objective: "Revenue Growth", kpis: ["Revenue Growth Rate", "New Customer Count", "Customer Retention Rate", "Customer Churn Rate", "Average Revenue Per Customer"] },
  { objective: "Profitability Improvement", kpis: ["Gross Margin", "Net Profit Margin", "Cost Per Service", "Customer Profitability", "Service Profitability"] },
  { objective: "Customer Experience", kpis: ["Customer Satisfaction Score", "Complaint Rate", "Complaint Resolution Time", "Response Time", "Customer Retention Rate"] },
  { objective: "Operational Efficiency", kpis: ["Process Cycle Time", "First-Time Resolution Rate", "Rework Rate", "Manual Process Ratio", "Approval Cycle Time"] },
  { objective: "Workforce Productivity", kpis: ["Tasks Completed Per Employee", "Hours Lost to Manual Work", "Employee Workload Balance", "Training Completion Rate", "System Adoption Rate"] },
  { objective: "Data Visibility", kpis: ["Report Preparation Time", "Data Accuracy Rate", "Duplicate Data Entry Rate", "KPI Availability Score", "Single Source of Truth Score"] },
  { objective: "Risk Reduction", kpis: ["Critical Process Dependency Count", "Compliance Issue Count", "System Downtime", "Supplier Risk Score", "Operational Risk Score"] },
  { objective: "Automation", kpis: ["Automation Rate", "Manual Task Count", "Workflow Automation Coverage", "Reporting Automation Rate", "Digital Form Usage Rate"] }
];

const tireKpiGroups = [
  { activity: "tire_wholesale_distribution", objective: "Operational Efficiency", label: "Tire Wholesale & Distribution", kpis: ["Inventory Accuracy", "Stockout Rate", "Inventory Turnover", "Delivery Lead Time", "Order Fulfillment Rate", "Slow-Moving Inventory Ratio"] },
  { activity: "mobile_tire_services", objective: "Operational Efficiency", label: "Mobile Tire Services", kpis: ["Average Dispatch Time", "Technician Utilization Rate", "Jobs Completed Per Technician", "Travel Time Per Job", "Service Completion Time", "First-Time Resolution Rate"] },
  { activity: "roadside_tire_assistance", objective: "Customer Experience", label: "Roadside Tire Assistance", kpis: ["Emergency Response Time", "SLA Compliance Rate", "Average Time to Assignment", "Average Time to Arrival", "Emergency Job Completion Time", "Customer Downtime"] },
  { activity: "fleet_tire_management", objective: "Profitability Improvement", label: "Fleet Tire Management", kpis: ["Tire Cost Per Kilometer", "Tire Failure Rate", "Fleet Service Response Time", "Fleet Contract Renewal Rate", "Preventive Service Completion Rate", "Tire Lifecycle Visibility Score"] },
  { activity: "tire_retreading", objective: "Profitability Improvement", label: "Tire Retreading", kpis: ["Casing Acceptance Rate", "Retread Yield Rate", "Retread Success Rate", "Retread Production Cycle Time", "Retread Quality Issue Rate", "Retread Profitability"] },
  { activity: "warehouse_operations", objective: "Operational Efficiency", label: "Warehouse Operations", kpis: ["Picking Accuracy", "Receiving Accuracy", "Warehouse Productivity", "Stock Transfer Time", "Inventory Reconciliation Time", "Warehouse Space Utilization"] }
];

const kpiRecommendationRules = {
  roadside_tire_assistance: ["emergency_response_time", "sla_compliance_rate", "average_time_to_assignment", "average_time_to_arrival", "emergency_job_completion_time", "customer_downtime"],
  mobile_tire_services: ["average_dispatch_time", "technician_utilization_rate", "jobs_completed_per_technician", "travel_time_per_job", "service_completion_time", "first_time_resolution_rate"],
  fleet_tire_management: ["tire_cost_per_kilometer", "tire_failure_rate", "fleet_service_response_time", "fleet_contract_renewal_rate", "preventive_service_completion_rate", "tire_lifecycle_visibility_score"],
  tire_retreading: ["casing_acceptance_rate", "retread_yield_rate", "retread_success_rate", "retread_production_cycle_time", "retread_quality_issue_rate", "retread_profitability"],
  warehouse_operations: ["inventory_accuracy", "stockout_rate", "inventory_turnover", "delivery_lead_time", "order_fulfillment_rate", "warehouse_productivity"],
  inventory_intensive: ["inventory_accuracy", "stockout_rate", "inventory_turnover", "delivery_lead_time", "order_fulfillment_rate", "warehouse_productivity"],
  distribution_network: ["inventory_accuracy", "stockout_rate", "inventory_turnover", "delivery_lead_time", "order_fulfillment_rate", "warehouse_productivity"]
};

const kpiMetricLibrary = {
  name: "Layer 13 KPI Discovery & Measurement Framework",
  purpose: [
    "Determine which KPIs the company should measure",
    "Identify which KPIs are already measured",
    "Identify which KPIs can be estimated from surveys, interviews, or operational records",
    "Treat missing KPI data as a business finding",
    "Define future data capture requirements for missing KPIs"
  ],
  businessObjectives: kpiBusinessObjectives,
  measurementStatuses: kpiMeasurementStatuses,
  schema: kpiDefinitionSchema,
  seedKpis: [
    ...universalKpiGroups.flatMap((group) => group.kpis.map((name) => buildKpiDefinition({ name, objective: group.objective, importance: 5, benchmark: true, roadmap: "quick_win" }))),
    ...tireKpiGroups.flatMap((group) =>
      group.kpis.map((name) =>
        buildKpiDefinition({
          name,
          objective: group.objective,
          industry: "tire_industry",
          activity: group.activity,
          description: `${name} measures ${group.label.toLowerCase()} performance for tire-industry assessments.`,
          importance: 5,
          difficulty: /profitability|lifecycle|utilization|downtime/i.test(name) ? 4 : 3,
          benchmark: /rate|time|accuracy|turnover|utilization/i.test(name),
          roadmap: /lifecycle|profitability|utilization|downtime/i.test(name) ? "optimization" : "foundation"
        })
      )
    )
  ],
  recommendationRules: kpiRecommendationRules,
  gapOutputSchema: {
    kpi_id: "",
    kpi_name: "",
    recommended: true,
    measurement_status: "",
    why_it_matters: "",
    required_data_points: [],
    recommended_data_capture_method: "",
    related_recommendation: "",
    roadmap_relevance: ""
  }
};

const analysisKnowledgeMap = {
  stakeholders: ["Owner", "Executive", "Operations Manager", "Branch Manager", "Dispatcher", "Technician", "Warehouse", "Finance", "Sales", "Customer", "Supplier", "IT"],
  domains: businessDomainsTaxonomy.map((domain) => domain.name),
  categories: assessmentCategoriesTaxonomy.map((category) => category.name),
  problemTypes: problemTypesTaxonomy.flatMap((group) => group.items.map((item) => item.name)),
  severityScale: Object.entries(scoringModel.severity).map(([score, label]) => `${score} ${label}`),
  frequencies: Object.entries(scoringModel.frequency).map(([score, label]) => `${score} ${label}`),
  impactDimensions: impactModel.dimensions.map((dimension) => dimension.name),
  rootCauses: ["People", "Process", "Technology", "Data", "Organization", "Governance"],
  opportunityClasses: recommendationEngine.types.map((type) => type.name),
  roadmapPhases: roadmapGenerator.phases.map((phase) => `${phase.id.replace("_", " ").toUpperCase()} ${phase.name}`)
};

const tireBusinessActivityGroups = [
  {
    group: { en: "Sales & Distribution", tr: "Satış ve Dağıtım" },
    items: [
      { id: "tire_retail", label: "Tire Retail", tr: "Lastik Perakende", description: "Selling tires directly to end customers." },
      { id: "tire_wholesale_distribution", label: "Tire Wholesale & Distribution", tr: "Lastik Toptan Satış ve Dağıtım", description: "Selling and supplying tires to dealers, fleets, branches, or business customers." },
      { id: "ecommerce_tire_sales", label: "E-Commerce Tire Sales", tr: "E-Ticaret Lastik Satışı", description: "Selling tires through online channels." },
      { id: "tire_importer", label: "Tire Importer", tr: "Lastik İthalatçısı", description: "Importing tires from international suppliers." },
      { id: "tire_exporter", label: "Tire Exporter", tr: "Lastik İhracatçısı", description: "Exporting tires to international customers or markets." }
    ]
  },
  {
    group: { en: "Service Operations", tr: "Servis Operasyonları" },
    items: [
      { id: "mobile_tire_services", label: "Mobile Tire Services", tr: "Mobil Lastik Hizmetleri", description: "Planned on-site tire services performed at customer locations." },
      { id: "roadside_tire_assistance", label: "Roadside Tire Assistance", tr: "Yol Yardım Lastik Hizmeti", description: "Emergency tire service for vehicles that cannot continue operating." },
      { id: "wheel_alignment_services", label: "Wheel Alignment Services", tr: "Rot Ayar Hizmetleri", description: "Alignment services for passenger, commercial, or fleet vehicles." }
    ]
  },
  {
    group: { en: "Fleet Operations", tr: "Filo Operasyonları" },
    items: [
      { id: "fleet_tire_management", label: "Fleet Tire Management", tr: "Filo Lastik Yönetimi", description: "Managing tire needs, performance, service, and replacement for fleet customers." },
      { id: "fleet_maintenance_services", label: "Fleet Maintenance Services", tr: "Filo Bakım Hizmetleri", description: "Providing broader maintenance services for fleet vehicles." },
      { id: "tire_performance_monitoring", label: "Tire Performance Monitoring", tr: "Lastik Performans Takibi", description: "Tracking tire performance, wear, usage, and related service data." },
      { id: "tire_lifecycle_management", label: "Tire Lifecycle Management", tr: "Lastik Yaşam Döngüsü Yönetimi", description: "Managing tires from purchase, installation, use, service, retreading, and end-of-life." },
      { id: "contract_fleet_services", label: "Contract Fleet Services", tr: "Sözleşmeli Filo Hizmetleri", description: "Recurring contract-based tire or maintenance services for fleet customers." }
    ]
  },
  {
    group: { en: "Retreading", tr: "Kaplama" },
    items: [
      { id: "tire_retreading", label: "Tire Retreading", tr: "Lastik Kaplama", description: "Retreading used tire casings to extend tire life." }
    ]
  },
  {
    group: { en: "Sustainability", tr: "Sürdürülebilirlik" },
    items: [
      { id: "tire_recycling", label: "Tire Recycling", tr: "Lastik Geri Dönüşümü", description: "Recycling end-of-life tires or managing tire recycling operations." }
    ]
  },
  {
    group: { en: "Manufacturing", tr: "Üretim" },
    items: [
      { id: "tire_manufacturing", label: "Tire Manufacturing", tr: "Lastik Üretimi", description: "Producing tires." },
      { id: "tire_component_manufacturing", label: "Tire Component Manufacturing", tr: "Lastik Bileşen Üretimi", description: "Producing components used in tire manufacturing." },
      { id: "private_label_tire_production", label: "Private Label Tire Production", tr: "Özel Marka Lastik Üretimi", description: "Producing tires under another company’s brand." }
    ]
  }
];

const tireSegmentsServed = [
  { id: "passenger_tires", label: "Passenger Tires", tr: "Binek Araç Lastikleri" },
  { id: "commercial_truck_tires", label: "Commercial Truck Tires", tr: "Ticari Kamyon Lastikleri" },
  { id: "bus_tires", label: "Bus Tires", tr: "Otobüs Lastikleri" },
  { id: "agricultural_tires", label: "Agricultural Tires", tr: "Tarım Lastikleri" },
  { id: "construction_otr_tires", label: "Construction & OTR Tires", tr: "İnşaat ve OTR Lastikleri" },
  { id: "industrial_tires", label: "Industrial Tires", tr: "Endüstriyel Lastikler" },
  { id: "mining_tires", label: "Mining Tires", tr: "Maden Lastikleri" },
  { id: "specialty_tires", label: "Specialty Tires", tr: "Özel Amaçlı Lastikler" },
  { id: "motorcycle_tires", label: "Motorcycle Tires", tr: "Motosiklet Lastikleri" }
];

const operationalCharacteristicGroups = [
  {
    group: { en: "Business Structure", tr: "İş Yapısı" },
    items: [
      { id: "multi_location_operations", label: "Multi-location Operations", tr: "Çok Lokasyonlu Operasyon" },
      { id: "warehouse_operations", label: "Warehouse Operations", tr: "Depo Operasyonları" },
      { id: "distribution_network", label: "Distribution Network", tr: "Dağıtım Ağı" },
      { id: "franchise_network", label: "Franchise Network", tr: "Franchise Ağı" }
    ]
  },
  {
    group: { en: "Workforce", tr: "İş Gücü" },
    items: [
      { id: "mobile_workforce", label: "Mobile Workforce", tr: "Mobil İş Gücü" },
      { id: "field_service_teams", label: "Field Service Teams", tr: "Saha Servis Ekipleri" }
    ]
  },
  {
    group: { en: "Revenue Model", tr: "Gelir Modeli" },
    items: [
      { id: "b2b_business", label: "B2B Business", tr: "B2B İş Modeli" },
      { id: "b2c_business", label: "B2C Business", tr: "B2C İş Modeli" },
      { id: "contract_based_revenue", label: "Contract-Based Revenue", tr: "Sözleşme Bazlı Gelir" }
    ]
  },
  {
    group: { en: "Operational Complexity", tr: "Operasyonel Karmaşıklık" },
    items: [
      { id: "inventory_intensive", label: "Inventory Intensive", tr: "Stok Yoğun Operasyon" },
      { id: "asset_intensive_operations", label: "Asset Intensive Operations", tr: "Varlık Yoğun Operasyon" },
      { id: "route_based_service", label: "Route-Based Service", tr: "Rota Bazlı Servis" },
      { id: "twenty_four_seven_operations", label: "24/7 Operations", tr: "7/24 Operasyon" },
      { id: "emergency_services", label: "Emergency Services", tr: "Acil Servis Hizmetleri" }
    ]
  },
  {
    group: { en: "Network Management", tr: "Ağ Yönetimi" },
    items: [
      { id: "service_network_management", label: "Service Network Management", tr: "Servis Ağı Yönetimi" },
      { id: "dealer_network_management", label: "Dealer Network Management", tr: "Bayi Ağı Yönetimi" }
    ]
  },
  {
    group: { en: "Customer Profile", tr: "Müşteri Profili" },
    items: [
      { id: "fleet_customer_focus", label: "Fleet Customer Focus", tr: "Filo Müşteri Odağı" },
      { id: "enterprise_customer_focus", label: "Enterprise Customer Focus", tr: "Kurumsal Müşteri Odağı" },
      { id: "government_customer_focus", label: "Government Customer Focus", tr: "Kamu Müşteri Odağı" }
    ]
  }
];

const strategicPriorityOptions = [
  { id: "revenue_growth", label: "Revenue Growth", tr: "Gelir Büyümesi" },
  { id: "profitability_improvement", label: "Profitability Improvement", tr: "Kârlılık İyileştirme" },
  { id: "cost_reduction", label: "Cost Reduction", tr: "Maliyet Azaltma" },
  { id: "operational_efficiency", label: "Operational Efficiency", tr: "Operasyonel Verimlilik" },
  { id: "geographic_expansion", label: "Geographic Expansion", tr: "Coğrafi Genişleme" },
  { id: "customer_retention", label: "Customer Retention", tr: "Müşteri Elde Tutma" },
  { id: "service_quality_improvement", label: "Service Quality Improvement", tr: "Servis Kalitesi İyileştirme" },
  { id: "workforce_productivity", label: "Workforce Productivity", tr: "İş Gücü Verimliliği" },
  { id: "automation", label: "Automation", tr: "Otomasyon" },
  { id: "digital_transformation", label: "Digital Transformation", tr: "Dijital Dönüşüm" },
  { id: "data_reporting_improvement", label: "Data & Reporting Improvement", tr: "Veri ve Raporlama İyileştirme" },
  { id: "sustainability", label: "Sustainability", tr: "Sürdürülebilirlik" }
];

const contextFieldGroups = [
  {
    title: { en: "Basic Company Information", tr: "Temel Şirket Bilgileri" },
    fields: [
      { id: "companyName", label: { en: "Company Name", tr: "Şirket Adı" }, type: "text", required: true },
      { id: "employeeRange", label: { en: "Number of Employees", tr: "Çalışan Sayısı" }, type: "select", required: true, options: ["1-10", "11-25", "26-50", "51-100", "101-250", "251+"] },
      { id: "locationCount", label: { en: "Number of Locations / Branches", tr: "Lokasyon / Şube Sayısı" }, type: "number", required: true },
      { id: "customerRange", label: { en: "Number of Active Customers", tr: "Aktif Müşteri Sayısı" }, type: "select", options: ["1-25", "26-100", "101-500", "501-1000", "1000+"] },
      { id: "revenueRange", label: { en: "Annual Revenue Range", tr: "Yıllık Ciro Aralığı" }, type: "select", options: ["Prefer not to say", "<$1M", "$1M-$5M", "$5M-$10M", "$10M-$50M", "$50M+"] },
      {
        id: "industry",
        label: { en: "Industry", tr: "Sektör" },
        type: "industry",
        required: true,
        options: [
          {
            id: "tire_industry",
            label: "Tire Industry",
            tr: "Lastik Sektörü",
            description: "Companies involved in tire sales, service, fleet tire management, retreading, manufacturing, distribution, or related operations.",
            trDescription: "Lastik satışı, servis, filo lastik yönetimi, kaplama, üretim, dağıtım veya ilişkili operasyonlarda faaliyet gösteren şirketler."
          }
        ]
      },
      {
        id: "tireIndustryActivities",
        label: { en: "Business activities", tr: "İş faaliyetleri" },
        type: "checkbox",
        required: true,
        dependsOnIndustry: "tire_industry",
        groupedOptions: tireBusinessActivityGroups
      },
      {
        id: "tireSegmentsServed",
        label: { en: "Tire segments served", tr: "Hizmet verilen lastik segmentleri" },
        type: "checkbox",
        dependsOnIndustry: "tire_industry",
        options: tireSegmentsServed
      },
      {
        id: "operationalCharacteristics",
        label: { en: "Operational characteristics", tr: "Operasyonel özellikler" },
        type: "checkbox",
        required: true,
        dependsOnIndustry: "tire_industry",
        groupedOptions: operationalCharacteristicGroups
      }
    ]
  },
  {
    title: { en: "Business Model", tr: "İş Modeli" },
    fields: [
      { id: "primaryActivity", label: { en: "What does your company primarily do?", tr: "Şirketiniz temel olarak ne iş yapıyor?" }, type: "textarea", required: true },
      { id: "revenueStreams", label: { en: "Primary revenue streams", tr: "Ana gelir kaynakları" }, type: "checkbox", required: true, options: ["Product Sales", "Services", "Contracts", "Subscription", "Manufacturing", "Retreading", "Roadside Service", "Fleet Service", "Other"] },
      { id: "mostImportantRevenue", label: { en: "Which revenue stream is most important today?", tr: "Bugün en önemli gelir kaynağı hangisi?" }, type: "text", required: true },
      { id: "fastestGrowingRevenue", label: { en: "Which revenue stream is growing fastest?", tr: "En hızlı büyüyen gelir kaynağı hangisi?" }, type: "text" }
    ]
  },
  {
    title: { en: "Organization Structure", tr: "Organizasyon Yapısı" },
    fields: [
      { id: "departments", label: { en: "Departments present", tr: "Şirkette bulunan departmanlar" }, type: "checkbox", required: true, options: ["Operations", "Warehouse", "Service", "Sales", "Finance", "HR", "IT", "Procurement", "Customer Service", "Dispatch", "Retreading", "Other"] },
      { id: "managerCount", label: { en: "Number of managers", tr: "Yönetici sayısı" }, type: "number" },
      { id: "fieldEmployeeCount", label: { en: "Number of field/service employees", tr: "Saha / servis çalışanı sayısı" }, type: "number" },
      { id: "operatingModel", label: { en: "Operating model", tr: "Operasyon modeli" }, type: "checkbox", required: true, options: ["Branches", "Mobile Teams", "Service Partners", "Central Operations", "Other"] }
    ]
  },
  {
    title: { en: "Technology Landscape", tr: "Teknoloji Altyapısı" },
    fields: [
      { id: "erpSystem", label: { en: "Which ERP system do you use?", tr: "Hangi ERP sistemini kullanıyorsunuz?" }, type: "text", required: true },
      { id: "crmSystem", label: { en: "Which CRM system do you use?", tr: "Hangi CRM sistemini kullanıyorsunuz?" }, type: "text" },
      { id: "accountingSystem", label: { en: "Which accounting/finance system do you use?", tr: "Hangi muhasebe/finans sistemini kullanıyorsunuz?" }, type: "text", required: true },
      { id: "communicationTools", label: { en: "Communication tools used daily", tr: "Günlük kullanılan iletişim araçları" }, type: "checkbox", required: true, options: ["Email", "WhatsApp", "Teams", "Slack", "Phone", "Paper", "Other"] },
      { id: "dailySystemCount", label: { en: "How many software systems are used daily by operations?", tr: "Operasyonda günlük kaç yazılım sistemi kullanılıyor?" }, type: "select", options: ["1", "2-3", "4-6", "7-10", "10+"] }
    ]
  },
  {
    title: { en: "Digital Maturity Self-Assessment", tr: "Dijital Olgunluk Öz Değerlendirmesi" },
    fields: ["reporting", "dataQuality", "automation", "customerExperience", "technology", "analytics", "processStandardization"].map((id) => ({
      id: `maturity_${id}`,
      label: {
        en: id.replace(/([A-Z])/g, " $1").replace(/^./, (char) => char.toUpperCase()),
        tr: {
          reporting: "Raporlama",
          dataQuality: "Veri Kalitesi",
          automation: "Otomasyon",
          customerExperience: "Müşteri Deneyimi",
          technology: "Teknoloji",
          analytics: "Analitik",
          processStandardization: "Süreç Standardizasyonu"
        }[id]
      },
      type: "scale",
      required: true
    }))
  },
  {
    title: { en: "Strategic Priorities", tr: "Stratejik Öncelikler" },
    fields: [
      { id: "topPriorities", label: { en: "Strategic priorities", tr: "Stratejik öncelikler" }, type: "checkbox", required: true, options: strategicPriorityOptions },
      { id: "mostUrgentPriority", label: { en: "Which priority is most urgent?", tr: "En acil öncelik hangisi?" }, type: "text", required: true },
      { id: "assessmentSuccess", label: { en: "What would make this assessment successful?", tr: "Bu değerlendirmeyi başarılı kılan sonuç ne olur?" }, type: "textarea", required: true }
    ]
  }
];

const contextGroupDescriptions = {
  "Basic Company Information": {
    en: "Company scale and industry taxonomy used to interpret complexity, maturity expectations, and ROI.",
    tr: "Karmaşıklık, olgunluk beklentisi ve yatırım etkisini yorumlamak için şirket ölçeği ve sektör sınıflandırması."
  },
  "Business Model": {
    en: "Clarifies how the company creates value and which revenue streams matter most.",
    tr: "Şirketin nasıl değer ürettiğini ve hangi gelir kaynaklarının önemli olduğunu netleştirir."
  },
  "Organization Structure": {
    en: "Maps the functions, management layer, and field execution model.",
    tr: "Fonksiyonları, yönetim katmanını ve saha çalışma modelini haritalar."
  },
  "Technology Landscape": {
    en: "Identifies core systems, communication tools, and integration complexity.",
    tr: "Ana sistemleri, iletişim araçlarını ve entegrasyon karmaşıklığını belirler."
  },
  "Digital Maturity Self-Assessment": {
    en: "Creates a starting benchmark that will be validated against survey evidence.",
    tr: "Anket bulguları ile karşılaştırılacak başlangıç dijital olgunluk göstergesini oluşturur."
  },
  "Strategic Priorities": {
    en: "Aligns analysis and recommendations with leadership priorities.",
    tr: "Analiz ve önerileri yönetim öncelikleriyle hizalar."
  }
};

const contextOptionTranslations = {
  "Tire Service": "Lastik Servisi",
  "Fleet Services": "Filo Hizmetleri",
  "Tire Sales & Distribution": "Lastik Satış ve Dağıtım",
  "Tire Retail": "Lastik Perakende",
  "Tire Wholesale": "Lastik Toptan Satış",
  "Tire Distribution": "Lastik Dağıtımı",
  "E-Commerce Tire Sales": "E-Ticaret Lastik Satışı",
  "Tire Importer": "Lastik İthalatçısı",
  "Tire Exporter": "Lastik İhracatçısı",
  "Tire Installation": "Lastik Montajı",
  "Mobile Tire Services": "Mobil Lastik Hizmetleri",
  "Tire Inspection Services": "Lastik Kontrol Hizmetleri",
  "Tire Repair Services": "Lastik Tamir Hizmetleri",
  "Roadside Tire Assistance": "Yol Yardım Lastik Hizmeti",
  "Tire Pressure Management": "Lastik Basınç Yönetimi",
  "Tire Rotation & Balancing": "Rotasyon ve Balans",
  "Wheel Alignment Services": "Rot Ayar Hizmetleri",
  "Fleet Tire Management": "Filo Lastik Yönetimi",
  "Fleet Tire Services": "Filo Lastik Hizmetleri",
  "Fleet Maintenance Services": "Filo Bakım Hizmetleri",
  "Fleet Inspection Services": "Filo Kontrol Hizmetleri",
  "Tire Performance Monitoring": "Lastik Performans Takibi",
  "Tire Lifecycle Management": "Lastik Yaşam Döngüsü Yönetimi",
  "Contract Fleet Services": "Sözleşmeli Filo Hizmetleri",
  "Tire Retreading": "Lastik Kaplama",
  "Tire Casing Inspection": "Karkas Kontrolü",
  "Tire Recycling": "Lastik Geri Dönüşümü",
  "Scrap Tire Management": "Hurda Lastik Yönetimi",
  "Tire Storage": "Lastik Depolama",
  "Seasonal Tire Storage": "Mevsimsel Lastik Depolama",
  "Tire Warehousing": "Lastik Depoculuğu",
  "Tire Logistics": "Lastik Lojistiği",
  "Tire Transportation": "Lastik Taşımacılığı",
  "Tire Manufacturing": "Lastik Üretimi",
  "Tire Component Manufacturing": "Lastik Bileşen Üretimi",
  "Private Label Tire Production": "Özel Marka Lastik Üretimi",
  "Passenger Tires": "Binek Araç Lastikleri",
  "Commercial Truck Tires": "Ticari Kamyon Lastikleri",
  "Bus Tires": "Otobüs Lastikleri",
  "Agricultural Tires": "Tarım Lastikleri",
  "Construction & OTR Tires": "İnşaat ve OTR Lastikleri",
  "Industrial Tires": "Endüstriyel Lastikler",
  "Mining Tires": "Maden Lastikleri",
  "Specialty Tires": "Özel Amaçlı Lastikler",
  "Motorcycle Tires": "Motosiklet Lastikleri",
  "Multi-location Operations": "Çok Lokasyonlu Operasyon",
  "Mobile Workforce": "Mobil İş Gücü",
  "Field Service Teams": "Saha Servis Ekipleri",
  "Inventory Intensive": "Stok Yoğun Operasyon",
  "B2B Business": "B2B İş Modeli",
  "B2C Business": "B2C İş Modeli",
  "Contract-Based Revenue": "Sözleşme Bazlı Gelir",
  "Route-Based Service": "Rota Bazlı Servis",
  "Service Network Management": "Servis Ağı Yönetimi",
  "Dealer Network Management": "Bayi Ağı Yönetimi",
  "Franchise Network": "Franchise Ağı",
  "Fleet Customer Focus": "Filo Müşteri Odağı",
  "Asset Intensive Operations": "Varlık Yoğun Operasyon",
  Manufacturing: "Üretim",
  Hospitality: "Konaklama",
  Logistics: "Lojistik",
  Distribution: "Dağıtım",
  Other: "Diğer",
  "Prefer not to say": "Belirtmek istemiyorum",
  "Product Sales": "Ürün Satışı",
  Services: "Hizmetler",
  Contracts: "Sözleşmeler",
  Subscription: "Abonelik",
  Retreading: "Kaplama",
  "Roadside Service": "Yol Yardım Servisi",
  "Fleet Service": "Filo Servisi",
  Operations: "Operasyon",
  Warehouse: "Depo",
  Service: "Servis",
  Sales: "Satış",
  Finance: "Finans",
  HR: "İK",
  IT: "BT",
  Procurement: "Satın Alma",
  "Customer Service": "Müşteri Hizmetleri",
  Dispatch: "Sevkiyat / Yönlendirme",
  Branches: "Şubeler",
  "Mobile Teams": "Mobil Ekipler",
  "Service Partners": "Servis Partnerleri",
  "Central Operations": "Merkezi Operasyon",
  Email: "E-posta",
  WhatsApp: "WhatsApp",
  Teams: "Teams",
  Slack: "Slack",
  Phone: "Telefon",
  Paper: "Kağıt",
  Growth: "Büyüme",
  Profitability: "Kârlılık",
  Efficiency: "Verimlilik",
  Expansion: "Genişleme",
  "Customer Experience": "Müşteri Deneyimi",
  "Cost Reduction": "Maliyet Azaltma",
  Standardization: "Standardizasyon",
  "Data Visibility": "Veri Görünürlüğü"
};

const problemTaxonomy = [
  { type: "Bottleneck", category: "Process", rootCause: ["Process"], keywords: ["bottleneck", "blocked", "waiting", "tıkan", "bekliyor"] },
  { type: "Delay", category: "Process", rootCause: ["Process"], keywords: ["delay", "late", "slow", "gecik", "yavaş"] },
  { type: "Rework", category: "Process", rootCause: ["Process", "Data"], keywords: ["rework", "again", "repeat", "tekrar", "yeniden"] },
  { type: "Manual Process", category: "Process", rootCause: ["Process", "Technology"], keywords: ["manual", "manuel", "paper", "form", "excel"] },
  { type: "Duplicate Activity", category: "Process", rootCause: ["Process", "Data"], keywords: ["duplicate", "double", "copy", "same data", "tekrar giriş", "kopya"] },
  { type: "Approval Delay", category: "Process", rootCause: ["Governance", "Process"], keywords: ["approval", "approve", "onay"] },
  { type: "Lack of Standardization", category: "Process", rootCause: ["Process", "Organization"], keywords: ["standard", "different", "varies", "standardizasyon", "farklı"] },
  { type: "Missing Ownership", category: "Governance", rootCause: ["Organization", "Governance"], keywords: ["owner", "responsible", "ownership", "sahip", "sorumlu"] },
  { type: "Missing Data", category: "Data", rootCause: ["Data", "Process"], keywords: ["missing data", "missing information", "eksik bilgi", "eksik veri"] },
  { type: "Inaccurate Data", category: "Data", rootCause: ["Data"], keywords: ["wrong", "incorrect", "inaccurate", "hatalı", "yanlış"] },
  { type: "Data Silos", category: "Data", rootCause: ["Data", "Technology"], keywords: ["silo", "separate", "not shared", "ayrı", "paylaşılmıyor"] },
  { type: "Reporting Gaps", category: "Data", rootCause: ["Data", "Technology"], keywords: ["report", "dashboard", "kpi", "rapor"] },
  { type: "No Single Source of Truth", category: "Data", rootCause: ["Data", "Governance"], keywords: ["single source", "truth", "which number", "tek kaynak"] },
  { type: "Missing Integration", category: "Technology", rootCause: ["Technology"], keywords: ["integration", "integrated", "connect", "entegrasyon", "bağlı değil"] },
  { type: "Poor Usability", category: "Technology", rootCause: ["Technology", "People"], keywords: ["hard to use", "difficult system", "kullanımı zor"] },
  { type: "Lack of Automation", category: "Technology", rootCause: ["Technology", "Process"], keywords: ["automation", "automate", "otomasyon", "otomatik"] },
  { type: "Spreadsheet Dependency", category: "Technology", rootCause: ["Technology", "Data"], keywords: ["spreadsheet", "excel"] },
  { type: "WhatsApp Dependency", category: "Technology", rootCause: ["Technology", "Process"], keywords: ["whatsapp"] },
  { type: "Training Gap", category: "People", rootCause: ["People"], keywords: ["training", "train", "eğitim"] },
  { type: "Knowledge Dependency", category: "People", rootCause: ["People", "Organization"], keywords: ["one person", "specific employee", "knowledge", "kişiye bağlı"] },
  { type: "Communication Problem", category: "People", rootCause: ["People", "Process"], keywords: ["communication", "communicate", "iletişim"] },
  { type: "Visibility Problem", category: "Customer Experience", rootCause: ["Data", "Technology"], keywords: ["visibility", "tracking", "view", "görünürlük", "takip"] },
  { type: "Slow Response", category: "Customer Experience", rootCause: ["Process", "People"], keywords: ["response", "waiting customer", "yanıt", "müşteri bekliyor"] },
  { type: "Billing Delay", category: "Financial", rootCause: ["Process", "Data"], keywords: ["billing", "invoice", "fatura"] },
  { type: "Inventory Waste", category: "Financial", rootCause: ["Inventory", "Data"], keywords: ["inventory", "stock", "stok", "envanter"] },
  { type: "Revenue Leakage", category: "Financial", rootCause: ["Financial", "Governance"], keywords: ["revenue", "lost sale", "leakage", "gelir"] }
];

const masterSurveyBank = [
  {
    stakeholder: "Owner / CEO",
    categories: [
      {
        name: "Vision & Strategy",
        prefix: "Q-CEO",
        questions: [
          "What are {organization_name}'s top three strategic priorities for the next three years?",
          "What are the biggest barriers preventing {organization_name} from achieving these priorities?",
          "What growth opportunities are most important to {organization_name}?",
          "Which business areas are expected to grow fastest?",
          "Which business areas create the most profit today?",
          "Which business areas require the most management attention?",
          "What risks concern you most?",
          "What market changes do you expect in the next five years?",
          "How do you define success for {organization_name}?",
          "If {organization_name} were transformed successfully, what would be different in three years?"
        ]
      },
      {
        name: "Leadership & Decision Making",
        prefix: "Q-CEO",
        start: 11,
        questions: [
          "How frequently do you review company performance?",
          "Which KPIs are most important to you?",
          "What information do you wish you could access instantly?",
          "How confident are you in the accuracy of current reports?",
          "How quickly can management identify operational problems?",
          "Which decisions take too long?",
          "Where do you feel visibility is lacking?",
          "What reports are difficult to obtain?",
          "What information is missing from management reports?",
          "What management decisions are based on assumptions rather than data?"
        ]
      },
      {
        name: "Digital Transformation",
        prefix: "Q-CEO",
        start: 21,
        questions: [
          "What digital initiatives have been attempted previously?",
          "Which initiatives delivered value?",
          "Which initiatives failed?",
          "What technologies are underutilized?",
          "What process would you digitize first?",
          "What process should never be disrupted?",
          "What business capabilities should technology improve most?",
          "How ready is the organization for change?",
          "What concerns do you have regarding transformation?",
          "What business outcomes should this project achieve?"
        ]
      }
    ]
  },
  {
    stakeholder: "Operations Manager",
    categories: [
      {
        name: "Process Management",
        prefix: "Q-OPS",
        questions: [
          "Describe your primary responsibilities.",
          "Which operational processes are most critical?",
          "Which processes generate the most delays?",
          "Which processes require the most manual effort?",
          "Which processes generate the most complaints?",
          "Which processes involve multiple departments?",
          "Which process would you redesign first?",
          "Where do approvals slow down work?",
          "Which process lacks standardization?",
          "What process failures occur repeatedly?"
        ]
      },
      {
        name: "Reporting & KPIs",
        prefix: "Q-OPS",
        start: 11,
        questions: [
          "Which KPIs do you monitor?",
          "How much time is spent preparing reports?",
          "What reports are generated manually?",
          "Which metrics are unavailable today?",
          "What information is difficult to access?",
          "How often are reports inaccurate?",
          "What data is missing?",
          "Which departments provide poor-quality data?",
          "What decisions are difficult due to lack of information?",
          "What dashboard would help you most?"
        ]
      }
    ]
  },
  {
    stakeholder: "Branch Manager",
    categories: [
      {
        name: "Branch Operations",
        prefix: "Q-BR",
        questions: [
          "What are the top operational challenges at your branch?",
          "What activities consume the most employee time?",
          "What causes service delays?",
          "What information is difficult to obtain?",
          "What causes customer dissatisfaction?",
          "Which tasks are repeated unnecessarily?",
          "Which approvals cause delays?",
          "Which reports are difficult to prepare?",
          "Which processes depend on specific employees?",
          "Which branch metrics do you monitor?"
        ]
      }
    ]
  },
  {
    stakeholder: "Customer Service / Dispatch",
    categories: [
      {
        name: "Service Requests",
        prefix: "Q-DSP",
        questions: [
          "How do requests arrive?",
          "What percentage arrive by phone?",
          "What percentage arrive by WhatsApp?",
          "What percentage arrive by email?",
          "What information is usually missing?",
          "How much time is spent gathering missing information?",
          "What causes scheduling delays?",
          "What requests require escalation?",
          "How often are requests reassigned?",
          "What causes customer frustration?"
        ]
      },
      {
        name: "Systems",
        prefix: "Q-DSP",
        start: 11,
        questions: [
          "Which systems are used daily?",
          "How many systems are required to process a request?",
          "Where is data entered more than once?",
          "Which systems are difficult to use?",
          "What information should be visible but is not?"
        ]
      }
    ]
  },
  {
    stakeholder: "Technician",
    categories: [
      {
        name: "Service Execution",
        prefix: "Q-TECH",
        questions: [
          "Describe your last service job.",
          "What information do you receive before arriving?",
          "What information is usually missing?",
          "What causes delays on-site?",
          "What tools or materials are often unavailable?",
          "What causes repeat visits?",
          "What documentation is required after service?",
          "Where do you record service information?",
          "How often do you duplicate information?",
          "What part of the job is most frustrating?"
        ]
      },
      {
        name: "Mobile Technology",
        prefix: "Q-TECH",
        start: 11,
        questions: [
          "Do you use mobile applications at work?",
          "What information would you like available on your phone?",
          "Would digital forms save time?",
          "Would photo-based reporting help?",
          "What mobile features would improve your work most?"
        ]
      }
    ]
  },
  {
    stakeholder: "Warehouse / Inventory",
    categories: [
      {
        name: "Inventory",
        prefix: "Q-WH",
        questions: [
          "How is inventory tracked?",
          "How often are stock counts inaccurate?",
          "What causes inventory discrepancies?",
          "Can inventory be viewed across all locations?",
          "What causes stock shortages?",
          "What inventory information is missing?",
          "How are replenishment decisions made?",
          "Which products are difficult to forecast?",
          "What inventory issues create the most cost?",
          "What inventory process should be improved first?"
        ]
      }
    ]
  },
  {
    stakeholder: "Finance",
    categories: [
      {
        name: "Finance",
        prefix: "Q-FIN",
        questions: [
          "What causes billing delays?",
          "What information is frequently missing?",
          "Which reports are generated manually?",
          "How many hours per week are spent preparing reports?",
          "Which costs are difficult to track?",
          "Which operational activities create unexpected costs?",
          "Which financial processes should be automated?",
          "Which data sources are unreliable?",
          "What profitability information is unavailable today?",
          "What financial dashboard would be most valuable?"
        ]
      }
    ]
  },
  {
    stakeholder: "Sales",
    categories: [
      {
        name: "Sales",
        prefix: "Q-SALES",
        questions: [
          "Why do customers choose {organization_name}?",
          "Why do customers leave {organization_name}?",
          "What services do customers request most often?",
          "What objections are encountered most frequently?",
          "Which competitors are strongest?",
          "Why are deals lost?",
          "What information would help you close more sales?",
          "What customer insights are missing?",
          "What sales activities consume the most time?",
          "What process should be improved first?"
        ]
      }
    ]
  },
  {
    stakeholder: "Customer",
    categories: [
      {
        name: "Customer",
        prefix: "Q-CUST",
        questions: [
          "Why did you choose {organization_name}?",
          "What does {organization_name} do well?",
          "What should {organization_name} improve?",
          "What information do you frequently request?",
          "Would online service tracking be valuable?",
          "Would tire performance reporting be valuable?",
          "Would a customer portal be valuable?",
          "What creates the most frustration?",
          "What would make {organization_name} a better partner?",
          "How likely are you to recommend {organization_name}?"
        ]
      }
    ]
  },
  {
    stakeholder: "Universal Questions",
    categories: [
      {
        name: "Asked to every stakeholder",
        prefix: "Q-ALL",
        questions: [
          "What is the biggest challenge in your daily work?",
          "What task consumes the most time?",
          "What information is hardest to obtain?",
          "What causes the most mistakes?",
          "What causes the most delays?",
          "What process should be improved first?",
          "What process should never change?",
          "What system do you use most often?",
          "What frustrates you most about current systems?",
          "If you could change one thing tomorrow, what would it be?"
        ]
      }
    ]
  }
];

const masterSurveyTurkishBank = [
  [["{organization_name} için önümüzdeki üç yılın en önemli stratejik öncelikleri nelerdir?", "{organization_name} için bu önceliklere ulaşmayı engelleyen en büyük bariyerler nelerdir?", "{organization_name} için en önemli büyüme fırsatları nelerdir?", "Hangi iş alanlarının en hızlı büyümesi bekleniyor?", "Bugün en fazla kâr yaratan iş alanları hangileridir?", "En fazla yönetim dikkati gerektiren iş alanları hangileridir?", "Sizi en çok endişelendiren riskler nelerdir?", "Önümüzdeki beş yılda hangi pazar değişimlerini bekliyorsunuz?", "{organization_name} için başarıyı nasıl tanımlıyorsunuz?", "{organization_name} başarılı şekilde dönüşmüş olsaydı, üç yıl sonra ne farklı olurdu?"], ["Şirket performansını ne sıklıkla gözden geçiriyorsunuz?", "Sizin için en önemli KPI'lar hangileridir?", "Hangi bilgilere anında erişebilmeyi isterdiniz?", "Mevcut raporların doğruluğuna ne kadar güveniyorsunuz?", "Yönetim operasyonel sorunları ne kadar hızlı tespit edebiliyor?", "Hangi kararlar fazla uzun sürüyor?", "Görünürlüğün eksik olduğunu nerelerde hissediyorsunuz?", "Hangi raporları elde etmek zor?", "Yönetim raporlarında hangi bilgiler eksik?", "Hangi yönetim kararları veriye değil varsayımlara dayanıyor?"], ["Daha önce hangi dijital girişimler denendi?", "Hangi girişimler değer yarattı?", "Hangi girişimler başarısız oldu?", "Hangi teknolojiler yeterince kullanılmıyor?", "İlk olarak hangi süreci dijitalleştirirdiniz?", "Hangi süreç kesinlikle kesintiye uğratılmamalı?", "Teknoloji en çok hangi iş kabiliyetlerini geliştirmeli?", "Organizasyon değişime ne kadar hazır?", "Dönüşümle ilgili hangi endişeleriniz var?", "Bu proje hangi iş sonuçlarını sağlamalı?"]],
  [["Birincil sorumluluklarınızı açıklayın.", "En kritik operasyonel süreçler hangileridir?", "En fazla gecikme yaratan süreçler hangileridir?", "En fazla manuel emek gerektiren süreçler hangileridir?", "En fazla şikâyet oluşturan süreçler hangileridir?", "Birden fazla departmanı içeren süreçler hangileridir?", "İlk olarak hangi süreci yeniden tasarlardınız?", "Onaylar işi nerelerde yavaşlatıyor?", "Hangi süreçte standartlaşma eksik?", "Hangi süreç hataları tekrar tekrar yaşanıyor?"], ["Hangi KPI'ları takip ediyorsunuz?", "Rapor hazırlamak için ne kadar zaman harcanıyor?", "Hangi raporlar manuel olarak hazırlanıyor?", "Bugün hangi metriklere erişilemiyor?", "Hangi bilgilere erişmek zor?", "Raporlar ne sıklıkla hatalı oluyor?", "Hangi veriler eksik?", "Hangi departmanlar düşük kaliteli veri sağlıyor?", "Bilgi eksikliği nedeniyle hangi kararlar zor alınıyor?", "Size en çok hangi dashboard yardımcı olurdu?"]],
  [["Şubenizdeki en önemli operasyonel zorluklar nelerdir?", "Hangi faaliyetler çalışanların en fazla zamanını alıyor?", "Servis gecikmelerine ne sebep oluyor?", "Hangi bilgileri elde etmek zor?", "Müşteri memnuniyetsizliğine ne sebep oluyor?", "Hangi görevler gereksiz yere tekrarlanıyor?", "Hangi onaylar gecikmeye sebep oluyor?", "Hangi raporları hazırlamak zor?", "Hangi süreçler belirli çalışanlara bağımlı?", "Hangi şube metriklerini takip ediyorsunuz?"]],
  [["Talepler nasıl geliyor?", "Taleplerin yüzde kaçı telefonla geliyor?", "Taleplerin yüzde kaçı WhatsApp ile geliyor?", "Taleplerin yüzde kaçı e-posta ile geliyor?", "Genellikle hangi bilgiler eksik oluyor?", "Eksik bilgileri toplamak için ne kadar zaman harcanıyor?", "Planlama gecikmelerine ne sebep oluyor?", "Hangi talepler eskalasyon gerektiriyor?", "Talepler ne sıklıkla yeniden atanıyor?", "Müşteri frustrasyonuna ne sebep oluyor?"], ["Günlük olarak hangi sistemler kullanılıyor?", "Bir talebi işlemek için kaç sistem gerekiyor?", "Veri nerelerde birden fazla kez giriliyor?", "Hangi sistemleri kullanmak zor?", "Görünür olması gereken ama görünmeyen hangi bilgiler var?"]],
  [["Son servis işinizi anlatın.", "Sahaya gitmeden önce size hangi bilgiler geliyor?", "Genellikle hangi bilgiler eksik oluyor?", "Sahada gecikmelere ne sebep oluyor?", "Hangi araçlar veya malzemeler sıklıkla bulunmuyor?", "Tekrar ziyaretlere ne sebep oluyor?", "Servis sonrası hangi dokümantasyon gerekiyor?", "Servis bilgilerini nereye kaydediyorsunuz?", "Bilgileri ne sıklıkla tekrar giriyorsunuz?", "İşin en sinir bozucu kısmı nedir?"], ["İşte mobil uygulama kullanıyor musunuz?", "Telefonunuzda hangi bilgilere erişmek isterdiniz?", "Dijital formlar zaman kazandırır mı?", "Fotoğraf bazlı raporlama yardımcı olur mu?", "Hangi mobil özellikler işinizi en çok iyileştirir?"]],
  [["Envanter nasıl takip ediliyor?", "Stok sayımları ne sıklıkla hatalı çıkıyor?", "Envanter farklarına ne sebep oluyor?", "Envanter tüm lokasyonlarda görülebiliyor mu?", "Stok eksikliklerine ne sebep oluyor?", "Hangi envanter bilgileri eksik?", "İkmal kararları nasıl alınıyor?", "Hangi ürünleri tahmin etmek zor?", "En fazla maliyet yaratan envanter sorunları nelerdir?", "İlk olarak hangi envanter süreci iyileştirilmeli?"]],
  [["Faturalama gecikmelerine ne sebep oluyor?", "Hangi bilgiler sık sık eksik oluyor?", "Hangi raporlar manuel olarak hazırlanıyor?", "Haftada kaç saat rapor hazırlamaya harcanıyor?", "Hangi maliyetleri takip etmek zor?", "Hangi operasyonel faaliyetler beklenmeyen maliyet yaratıyor?", "Hangi finansal süreçler otomatikleştirilmeli?", "Hangi veri kaynakları güvenilir değil?", "Bugün hangi kârlılık bilgilerine erişilemiyor?", "En değerli finans dashboard'u ne olurdu?"]],
  [["Müşteriler neden {organization_name} ile çalışmayı seçiyor?", "Müşteriler neden {organization_name} ile çalışmayı bırakıyor?", "Müşteriler en çok hangi hizmetleri talep ediyor?", "En sık hangi itirazlarla karşılaşılıyor?", "En güçlü rakipler hangileri?", "Anlaşmalar neden kaybediliyor?", "Daha fazla satış kapatmanıza hangi bilgiler yardımcı olur?", "Hangi müşteri içgörüleri eksik?", "Hangi satış faaliyetleri en fazla zamanı alıyor?", "İlk olarak hangi süreç iyileştirilmeli?"]],
  [["{organization_name} ile çalışmayı neden seçtiniz?", "{organization_name} neyi iyi yapıyor?", "{organization_name} neyi geliştirmeli?", "Hangi bilgileri sık sık talep ediyorsunuz?", "Online servis takibi değerli olur mu?", "Lastik performans raporlaması değerli olur mu?", "Müşteri portalı değerli olur mu?", "En fazla frustrasyonu ne yaratıyor?", "{organization_name} ile daha değerli bir iş ortaklığı kurmak için ne değişmeli?", "{organization_name} tavsiye etme olasılığınız nedir?"]],
  [["Günlük işinizdeki en büyük zorluk nedir?", "En fazla zamanınızı alan görev nedir?", "Elde edilmesi en zor bilgi nedir?", "En fazla hataya ne sebep oluyor?", "En fazla gecikmeye ne sebep oluyor?", "İlk olarak hangi süreç iyileştirilmeli?", "Hangi süreç kesinlikle değişmemeli?", "En sık hangi sistemi kullanıyorsunuz?", "Mevcut sistemlerde sizi en çok ne rahatsız ediyor?", "Yarın bir şeyi değiştirebilseydiniz, bu ne olurdu?"]]
];

const templates = [
  {
    id: "owner",
    name: "Owner",
    focus: "Strategy, growth, risk, and investment priorities",
    questions: [
      "What are {organization_name}'s most important strategic goals for the next 3 years?",
      "Which operational problems limit growth, quality, or speed today?",
      "Where do you believe {organization_name} loses the most time, money, or visibility?",
      "Which decisions should management be able to make faster with better data?",
      "What would make this digital transformation successful in your eyes?"
    ]
  },
  {
    id: "general-manager",
    name: "General Manager",
    focus: "Company-wide priorities, performance, coordination, and transformation ownership",
    questions: [
      "Which business goals should digital transformation directly support?",
      "Which departments need better coordination or visibility?",
      "Which reports or KPIs should be standardized for management?",
      "Where do current systems limit execution quality or speed?",
      "Which initiatives should be prioritized in the first 6 months?"
    ]
  },
  {
    id: "operations-manager",
    name: "Operations Manager",
    focus: "Service operations, dispatch, branch execution, and bottlenecks",
    questions: [
      "Which recurring process creates the most delays for your team?",
      "Which reports do you prepare manually today?",
      "Where do approvals, missing data, or handoffs slow work down?",
      "Which system or data source do you trust least?",
      "Which operational KPI should management see weekly?"
    ]
  },
  {
    id: "branch-managers",
    name: "Branch Managers",
    focus: "Branch performance, approvals, local service execution, and customer response",
    questions: [
      "Which branch workflows are most difficult to manage consistently?",
      "Where do approvals, stock checks, or customer updates create delays?",
      "Which branch KPIs should be visible to management?",
      "Which tools do branch teams use outside the main system?",
      "What would improve service quality and accountability at branch level?"
    ]
  },
  {
    id: "sales-manager",
    name: "Sales Manager",
    focus: "Customer pipeline, quote flow, account visibility, and commercial reporting",
    questions: [
      "Where does the sales or quote process slow down?",
      "Which customer information is difficult to access or trust?",
      "Which reports would improve account management?",
      "How should sales connect with service and inventory data?",
      "Which customer-facing digital features would create commercial value?"
    ]
  },
  {
    id: "finance-manager",
    name: "Finance Manager",
    focus: "Invoicing, reporting, cost visibility, approvals, and financial controls",
    questions: [
      "Which finance workflows rely on manual checks or repeated data entry?",
      "Where do invoice delays or mismatches occur?",
      "Which operational costs need better visibility?",
      "Which reports should be automated first?",
      "What controls or approval flows should be digitized?"
    ]
  },
  {
    id: "dispatcher",
    name: "Dispatcher / Customer Service Coordinator",
    focus: "Service intake, scheduling, branch coordination, and technician communication",
    questions: [
      "How are service requests received and assigned today?",
      "Which information is often missing before dispatching service?",
      "Where do branch approvals or technician updates slow the process?",
      "Which communication happens outside formal systems?",
      "What would make dispatch faster and more reliable?"
    ]
  },
  {
    id: "customer-service",
    name: "Customer Service",
    focus: "Customer requests, follow-up, complaints, reporting, and communication history",
    questions: [
      "Which customer requests are hardest to track end to end?",
      "Where do customers ask for updates most often?",
      "Which complaint themes repeat?",
      "Which customer reports are prepared manually?",
      "What would improve customer communication quality?"
    ]
  },
  {
    id: "technician",
    name: "Technicians",
    focus: "Mobile work, field service, inspections, photos, and completion proof",
    questions: [
      "What information do you need before going to a service location?",
      "How do you record tire condition, photos, measurements, and service results today?",
      "Which field tasks are hardest to report accurately from mobile?",
      "What causes delays in service completion or customer approval?",
      "What would a useful technician mobile workflow include?"
    ]
  },
  {
    id: "warehouse",
    name: "Warehouse",
    focus: "Inventory accuracy, availability, branch requests, and replenishment",
    questions: [
      "Where does inventory visibility break down today?",
      "Which branch requests are hardest to fulfill quickly?",
      "Which stock movements are recorded late or manually?",
      "What causes mismatch between physical and system inventory?",
      "What should be automated first in warehouse coordination?"
    ]
  },
  {
    id: "fleet-customers",
    name: "Fleet Customers",
    focus: "Visibility, speed, reporting, trust, and service experience",
    questions: [
      "How do you request service from {organization_name} today?",
      "What information do you expect after a service or inspection is completed?",
      "Where do you need better visibility into fleet tire costs, history, or risk?",
      "Which reports would help you make better fleet decisions?",
      "What would make {organization_name} more valuable as a fleet partner?"
    ]
  },
  {
    id: "service-partners",
    name: "Service Partners",
    focus: "Partner coordination, service standards, reporting, and network performance",
    questions: [
      "How do you receive service requests or assignments from {organization_name}?",
      "Which information is missing or delayed during coordination?",
      "How do you report service completion and evidence today?",
      "Where should standards, approvals, or documentation be improved?",
      "What would make partner coordination easier and more reliable?"
    ]
  },
  {
    id: "supplier",
    name: "Supplier",
    focus: "Supplier reliability, delivery performance, inventory impact, order accuracy, and planning",
    questions: [
      "Which products or services do you provide?",
      "How predictable is demand and order volume?",
      "Where do order accuracy, lead time, or quality issues occur?",
      "Which collaboration improvements would reduce supply risk?",
      "What would make supplier coordination more reliable?"
    ]
  },
  {
    id: "it-manager",
    name: "IT / Systems",
    focus: "Systems, integrations, data quality, security, support, and automation readiness",
    questions: [
      "Which core systems are used across the business?",
      "Where are the biggest integration or data flow gaps?",
      "Which system issues interrupt daily operations?",
      "Where do employees use unofficial workarounds?",
      "Which data or system improvement should be prioritized first?"
    ]
  },
  {
    id: "hr-manager",
    name: "HR / Workforce",
    focus: "Workforce capacity, training, retention, workload balance, and change readiness",
    questions: [
      "Which workforce areas are hardest to staff?",
      "Where do training or skill gaps affect performance?",
      "Which teams experience the highest workload pressure?",
      "Where does key-person dependency create risk?",
      "Which workforce improvement should be prioritized first?"
    ]
  }
];

const templateTranslations = {
  owner: {
    name: "Sahip / CEO",
    focus: "Strateji, büyüme, risk ve yatırım öncelikleri",
    questions: [
      "{organization_name} için önümüzdeki 3 yılın en önemli stratejik hedefleri nelerdir?",
      "Bugün büyümeyi, kaliteyi veya hızı sınırlayan operasyonel problemler hangileridir?",
      "{organization_name} için en çok zaman, para veya görünürlük kaybı yaşanan alanlar nerelerdir?",
      "Yönetim hangi kararları daha iyi veriyle daha hızlı alabilmelidir?",
      "Bu dijital dönüşümün sizin gözünüzde başarılı olması için ne değişmiş olmalı?"
    ]
  },
  "general-manager": {
    name: "Genel Müdür",
    focus: "Şirket öncelikleri, performans, koordinasyon ve dönüşüm sahipliği",
    questions: [
      "Dijital dönüşüm doğrudan hangi iş hedeflerini desteklemelidir?",
      "Hangi departmanlarda daha iyi koordinasyon veya görünürlük gerekiyor?",
      "Yönetim için hangi raporlar veya KPI'lar standart hale getirilmelidir?",
      "Mevcut sistemler uygulama kalitesini veya hızı nerelerde sınırlandırıyor?",
      "İlk 6 ayda hangi girişimler önceliklendirilmelidir?"
    ]
  },
  "operations-manager": {
    name: "Operasyon Müdürü",
    focus: "Servis operasyonları, sevkiyat, şube uygulaması ve darboğazlar",
    questions: [
      "Ekibiniz için en çok gecikme yaratan tekrar eden süreç hangisidir?",
      "Bugün hangi raporları manuel olarak hazırlıyorsunuz?",
      "Onaylar, eksik veri veya devir teslimler işi nerelerde yavaşlatıyor?",
      "En az güvendiğiniz sistem veya veri kaynağı hangisidir?",
      "Yönetim hangi operasyonel KPI'ı haftalık olarak görmelidir?"
    ]
  },
  "branch-managers": {
    name: "Şube Müdürleri",
    focus: "Şube performansı, onaylar, yerel servis uygulaması ve müşteri yanıtı",
    questions: [
      "Hangi şube iş akışlarını tutarlı şekilde yönetmek en zordur?",
      "Onaylar, stok kontrolleri veya müşteri bilgilendirmeleri nerelerde gecikme yaratıyor?",
      "Hangi şube KPI'ları yönetim tarafından görünür olmalıdır?",
      "Şube ekipleri ana sistem dışında hangi araçları kullanıyor?",
      "Şube seviyesinde servis kalitesini ve hesap verebilirliği ne iyileştirir?"
    ]
  },
  "sales-manager": {
    name: "Satış Müdürü",
    focus: "Müşteri hattı, teklif akışı, hesap görünürlüğü ve ticari raporlama",
    questions: [
      "Satış veya teklif süreci nerede yavaşlıyor?",
      "Hangi müşteri bilgilerine erişmek veya güvenmek zor?",
      "Hangi raporlar hesap yönetimini iyileştirir?",
      "Satış, servis ve envanter verisiyle nasıl bağlanmalıdır?",
      "Hangi müşteri odaklı dijital özellikler ticari değer yaratır?"
    ]
  },
  "finance-manager": {
    name: "Finans Müdürü",
    focus: "Faturalama, raporlama, maliyet görünürlüğü, onaylar ve finansal kontroller",
    questions: [
      "Hangi finans iş akışları manuel kontrol veya tekrar veri girişine dayanıyor?",
      "Fatura gecikmeleri veya uyumsuzluklar nerelerde oluşuyor?",
      "Hangi operasyonel maliyetler için daha iyi görünürlük gerekiyor?",
      "İlk olarak hangi raporlar otomatikleştirilmelidir?",
      "Hangi kontrol veya onay akışları dijitalleştirilmelidir?"
    ]
  },
  dispatch: {
    name: "Sevkiyat / Dispatch",
    focus: "Servis talebi alımı, planlama, şube koordinasyonu ve teknisyen iletişimi",
    questions: [
      "Servis talepleri bugün nasıl alınıyor ve atanıyor?",
      "Servise yönlendirme öncesinde hangi bilgiler sıkça eksik oluyor?",
      "Şube onayları veya teknisyen güncellemeleri süreci nerede yavaşlatıyor?",
      "Hangi iletişimler resmi sistemlerin dışında gerçekleşiyor?",
      "Sevkiyatı daha hızlı ve güvenilir hale ne getirir?"
    ]
  },
  "customer-service": {
    name: "Müşteri Hizmetleri",
    focus: "Müşteri talepleri, takip, şikayetler, raporlama ve iletişim geçmişi",
    questions: [
      "Hangi müşteri taleplerini uçtan uca takip etmek en zordur?",
      "Müşteriler en çok hangi konularda güncelleme istiyor?",
      "Hangi şikayet temaları tekrar ediyor?",
      "Hangi müşteri raporları manuel hazırlanıyor?",
      "Müşteri iletişim kalitesini ne iyileştirir?"
    ]
  },
  technician: {
    name: "Teknisyenler",
    focus: "Mobil çalışma, saha servisi, kontroller, fotoğraflar ve tamamlama kanıtı",
    questions: [
      "Servis lokasyonuna gitmeden önce hangi bilgilere ihtiyaç duyuyorsunuz?",
      "Lastik durumu, fotoğraf, ölçüm ve servis sonuçlarını bugün nasıl kaydediyorsunuz?",
      "Mobil ortamdan doğru raporlanması en zor saha görevleri hangileridir?",
      "Servis tamamlama veya müşteri onayında gecikmeye ne sebep oluyor?",
      "Faydalı bir teknisyen mobil iş akışı neleri içermelidir?"
    ]
  },
  warehouse: {
    name: "Depo",
    focus: "Envanter doğruluğu, bulunabilirlik, şube talepleri ve ikmal",
    questions: [
      "Bugün envanter görünürlüğü nerede kopuyor?",
      "Hangi şube taleplerini hızlı karşılamak en zor?",
      "Hangi stok hareketleri geç veya manuel kaydediliyor?",
      "Fiziksel envanter ile sistem envanteri arasındaki farklara ne sebep oluyor?",
      "Depo koordinasyonunda ilk olarak ne otomatikleştirilmelidir?"
    ]
  },
  "fleet-customers": {
    name: "Filo Müşterileri",
    focus: "Görünürlük, hız, raporlama, güven ve servis deneyimi",
    questions: [
      "Bugün {organization_name} üzerinden nasıl servis talep ediyorsunuz?",
      "Bir servis veya kontrol tamamlandıktan sonra hangi bilgileri bekliyorsunuz?",
      "Filo lastik maliyetleri, geçmişi veya riskleri konusunda nerede daha iyi görünürlük gerekiyor?",
      "Hangi raporlar daha iyi filo kararları almanıza yardımcı olur?",
      "{organization_name} ile daha değerli bir filo iş ortaklığı kurmak için ne değişmeli?"
    ]
  },
  "service-partners": {
    name: "Servis Partnerleri",
    focus: "Partner koordinasyonu, servis standartları, raporlama ve ağ performansı",
    questions: [
      "{organization_name} üzerinden servis taleplerini veya atamaları nasıl alıyorsunuz?",
      "Koordinasyon sırasında hangi bilgiler eksik veya geç geliyor?",
      "Servis tamamlamayı ve kanıtları bugün nasıl raporluyorsunuz?",
      "Standartlar, onaylar veya dokümantasyon nerede iyileştirilmelidir?",
      "Partner koordinasyonunu daha kolay ve güvenilir hale ne getirir?"
    ]
  }
};

const composerState = {
  questions: []
};

const universalComposerQuestions = [
  {
    id: "Q-ALL-001",
    category: "Process",
    domains: ["Operations", "People"],
    problemTypes: ["Bottleneck", "Manual Process", "Delay"],
    industries: ["all"],
    kpiPotential: 3,
    aiValue: 5,
    en: "What is the biggest challenge in your daily work?",
    tr: "Günlük işinizdeki en büyük zorluk nedir?"
  },
  {
    id: "Q-ALL-002",
    category: "Process",
    domains: ["Operations", "Reporting"],
    problemTypes: ["Manual Process", "Duplicate Activity"],
    industries: ["all"],
    kpiPotential: 4,
    aiValue: 5,
    en: "What task consumes the most time?",
    tr: "En çok zaman alan görev hangisidir?"
  },
  {
    id: "Q-ALL-003",
    category: "Data",
    domains: ["Data", "Reporting"],
    problemTypes: ["Missing Data", "Reporting Gaps", "No Single Source of Truth"],
    industries: ["all"],
    kpiPotential: 4,
    aiValue: 5,
    en: "What information is hardest to obtain?",
    tr: "Ulaşılması en zor bilgi hangisidir?"
  },
  {
    id: "Q-ALL-004",
    category: "Risk",
    domains: ["Operations", "Quality"],
    problemTypes: ["Inaccurate Data", "Rework", "Process Complexity"],
    industries: ["all"],
    kpiPotential: 4,
    aiValue: 5,
    en: "What causes the most mistakes?",
    tr: "En çok hataya ne sebep oluyor?"
  },
  {
    id: "Q-ALL-005",
    category: "Process",
    domains: ["Operations", "Service Delivery"],
    problemTypes: ["Delay", "Approval Delay", "Bottleneck"],
    industries: ["all"],
    kpiPotential: 5,
    aiValue: 5,
    en: "What causes the most delays?",
    tr: "En çok gecikmeye ne sebep oluyor?"
  }
];

const industryQuestionPacks = [
  {
    id: "FLEET-001",
    stakeholderIds: ["owner", "general-manager", "operations-manager", "branch-managers", "fleet-customers"],
    category: "Customer Experience",
    domains: ["Service Delivery", "Customer Service", "Reporting"],
    problemTypes: ["Visibility Problem", "Reporting Gaps", "Slow Response"],
    industries: ["fleet", "tire", "tyre", "retread", "roadside", "service", "commercial vehicle"],
    kpiPotential: 5,
    aiValue: 5,
    en: "Where do fleet customers need better visibility into tire history, cost, risk, or service status?",
    tr: "Filo müşterileri lastik geçmişi, maliyet, risk veya servis durumu konusunda nerede daha iyi görünürlüğe ihtiyaç duyuyor?"
  },
  {
    id: "FLEET-002",
    stakeholderIds: ["technician", "dispatch", "operations-manager"],
    category: "Technology",
    domains: ["Service Delivery", "Technology", "Operations"],
    problemTypes: ["Missing Data", "Mobile Workflow Gap", "Manual Process"],
    industries: ["fleet", "tire", "tyre", "field service", "roadside", "retread"],
    kpiPotential: 5,
    aiValue: 5,
    en: "Which field service information should be captured by technicians on mobile, including photos, measurements, approvals, and completion proof?",
    tr: "Fotoğraf, ölçüm, onay ve tamamlama kanıtı dahil olmak üzere teknisyenler hangi saha servis bilgilerini mobil olarak kaydetmelidir?"
  },
  {
    id: "FLEET-003",
    stakeholderIds: ["warehouse", "branch-managers", "operations-manager", "finance-manager"],
    category: "Data",
    domains: ["Inventory", "Finance", "Operations"],
    problemTypes: ["Inventory Waste", "Inaccurate Data", "Data Silos"],
    industries: ["fleet", "tire", "tyre", "warehouse", "inventory", "retread"],
    kpiPotential: 5,
    aiValue: 5,
    en: "Where does inventory visibility fail between warehouse, branches, service teams, and finance?",
    tr: "Depo, şubeler, servis ekipleri ve finans arasında envanter görünürlüğü nerede kopuyor?"
  },
  {
    id: "MFG-001",
    stakeholderIds: ["operations-manager", "warehouse", "finance-manager", "general-manager"],
    category: "Process",
    domains: ["Operations", "Procurement", "Inventory"],
    problemTypes: ["Bottleneck", "Data Silos", "Reporting Gaps"],
    industries: ["manufacturing", "production", "factory", "procurement"],
    kpiPotential: 5,
    aiValue: 5,
    en: "Where do production, procurement, warehouse, and finance lose synchronization?",
    tr: "Üretim, satın alma, depo ve finans nerede senkronizasyon kaybediyor?"
  },
  {
    id: "HOTEL-001",
    stakeholderIds: ["general-manager", "customer-service", "finance-manager", "operations-manager"],
    category: "Customer Experience",
    domains: ["Customer Service", "Operations", "Finance"],
    problemTypes: ["Slow Response", "Visibility Problem", "Manual Process"],
    industries: ["hotel", "hospitality", "guest", "booking"],
    kpiPotential: 4,
    aiValue: 5,
    en: "Where does the guest journey lose visibility between booking, front desk, housekeeping, maintenance, and billing?",
    tr: "Rezervasyon, resepsiyon, kat hizmetleri, bakım ve faturalama arasında misafir yolculuğunda görünürlük nerede kayboluyor?"
  }
];

const stakeholderContextCopy = {
  owner: {
    en: { context: "Strategic Area", contextPlaceholder: "Example: Growth, reporting, investment decisions", process: "Decision Area", processPlaceholder: "Example: Management visibility" },
    tr: { context: "Stratejik Alan", contextPlaceholder: "Örnek: Büyüme, raporlama, yatırım kararları", process: "Karar Alanı", processPlaceholder: "Örnek: Yönetim görünürlüğü" }
  },
  "general-manager": {
    en: { context: "Business Area", contextPlaceholder: "Example: Operations, sales, finance", process: "Management Process", processPlaceholder: "Example: Performance review" },
    tr: { context: "İş Alanı", contextPlaceholder: "Örnek: Operasyon, satış, finans", process: "Yönetim Süreci", processPlaceholder: "Örnek: Performans değerlendirme" }
  },
  "fleet-customers": {
    en: { context: "Customer Company", contextPlaceholder: "Your company / fleet", process: "Service Experience", processPlaceholder: "Example: Service request, reporting, tracking" },
    tr: { context: "Müşteri Şirketi", contextPlaceholder: "Şirketiniz / filonuz", process: "Servis Deneyimi", processPlaceholder: "Örnek: Servis talebi, raporlama, takip" }
  },
  "service-partners": {
    en: { context: "Partner Company", contextPlaceholder: "Your company / service region", process: "Partner Workflow", processPlaceholder: "Example: Assignment, reporting, approval" },
    tr: { context: "Partner Şirket", contextPlaceholder: "Şirketiniz / servis bölgeniz", process: "Partner İş Akışı", processPlaceholder: "Örnek: Atama, raporlama, onay" }
  },
  technician: {
    en: { context: "Branch / Team", contextPlaceholder: "Example: Mobile service team", process: "Field Service Process", processPlaceholder: "Example: Tire inspection, roadside service" },
    tr: { context: "Şube / Ekip", contextPlaceholder: "Örnek: Mobil servis ekibi", process: "Saha Servis Süreci", processPlaceholder: "Örnek: Lastik kontrolü, yol yardımı" }
  },
  warehouse: {
    en: { context: "Warehouse / Location", contextPlaceholder: "Example: Main warehouse", process: "Inventory Process", processPlaceholder: "Example: Replenishment, stock transfer" },
    tr: { context: "Depo / Lokasyon", contextPlaceholder: "Örnek: Ana depo", process: "Envanter Süreci", processPlaceholder: "Örnek: İkmal, stok transferi" }
  }
};

const operationsManagerQuestionBankV1 = [
  {
    "question_id": "OPS-001",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Role & Responsibility",
    "question_text": "Which operational areas are you directly responsible for?",
    "response_type": "multiple_choice",
    "options": [
      "Service Delivery",
      "Field Operations",
      "Branch Operations",
      "Warehouse Operations",
      "Inventory Management",
      "Procurement",
      "Logistics",
      "Customer Service",
      "Finance Coordination",
      "Reporting",
      "Other"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "governance",
    "assessment_category": "governance",
    "problem_types_detectable": [
      "unclear_ownership",
      "process_complexity"
    ],
    "impact_dimensions": [
      "time_impact",
      "risk_impact"
    ],
    "maturity_dimensions": [
      "Leadership",
      "Operations"
    ],
    "kpi_outputs": [
      "operations_scope_coverage"
    ],
    "ai_analysis_purpose": "Identify the operational scope controlled by the Operations Manager and detect ownership complexity.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which areas require the most daily attention?",
      "Which areas have unclear ownership or shared accountability?"
    ],
    "recommendation_triggers": [
      "operational_governance_map",
      "role_and_ownership_clarification"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "medium"
  },
  {
    "question_id": "OPS-002",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Role & Responsibility",
    "question_text": "How clearly are responsibilities defined across operations teams?",
    "response_type": "scale_1_5",
    "options": [
      "1 = Not defined",
      "2 = Partially defined",
      "3 = Mostly defined",
      "4 = Clearly defined",
      "5 = Fully defined and documented"
    ],
    "required": true,
    "score_mapping": {
      "1": 5,
      "2": 4,
      "3": 3,
      "4": 2,
      "5": 1
    },
    "business_domain": "governance",
    "assessment_category": "governance",
    "problem_types_detectable": [
      "unclear_ownership",
      "lack_of_standardization",
      "communication_breakdown"
    ],
    "impact_dimensions": [
      "time_impact",
      "risk_impact",
      "employee_impact"
    ],
    "maturity_dimensions": [
      "Leadership",
      "Operations"
    ],
    "kpi_outputs": [
      "role_clarity_score"
    ],
    "ai_analysis_purpose": "Measure operational role clarity and identify ownership-related root causes.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Where do responsibility conflicts occur most often?",
      "Which processes suffer most from unclear ownership?"
    ],
    "recommendation_triggers": [
      "responsibility_matrix",
      "process_owner_assignment"
    ],
    "roadmap_relevance": "quick_win",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-003",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Operational Priorities",
    "question_text": "Rank the top operational priorities for the next 12 months.",
    "response_type": "ranking",
    "options": [
      "Reduce service delays",
      "Improve customer visibility",
      "Improve inventory accuracy",
      "Increase workforce productivity",
      "Reduce manual reporting",
      "Standardize branch operations",
      "Improve profitability",
      "Reduce operational risk",
      "Improve technology adoption"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "strategy",
    "assessment_category": "governance",
    "problem_types_detectable": [
      "bottleneck",
      "reporting_gap",
      "inventory_waste",
      "workload_imbalance",
      "operational_risk"
    ],
    "impact_dimensions": [
      "time_impact",
      "cost_impact",
      "customer_impact",
      "revenue_impact",
      "risk_impact"
    ],
    "maturity_dimensions": [
      "Strategy",
      "Operations"
    ],
    "kpi_outputs": [
      "priority_rankings"
    ],
    "ai_analysis_purpose": "Connect operational priorities to business objectives and roadmap themes.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Why did you rank the top priority first?",
      "Which priority would create the fastest measurable business impact?"
    ],
    "recommendation_triggers": [
      "executive_priority_alignment",
      "operations_roadmap_prioritization"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-004",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Operational Priorities",
    "question_text": "What is the most important operational KPI you currently monitor?",
    "response_type": "open_text",
    "options": [],
    "required": true,
    "score_mapping": {},
    "business_domain": "reporting_analytics",
    "assessment_category": "reporting",
    "problem_types_detectable": [
      "reporting_gap",
      "missing_data",
      "no_single_source_of_truth"
    ],
    "impact_dimensions": [
      "time_impact",
      "risk_impact"
    ],
    "maturity_dimensions": [
      "Analytics",
      "Operations"
    ],
    "kpi_outputs": [
      "current_primary_operations_kpi"
    ],
    "ai_analysis_purpose": "Identify the current KPI anchor for operations and compare it with the platform KPI library.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Where is this KPI tracked?",
      "How often is it reviewed?",
      "Who owns the accuracy of this KPI?",
      "Please provide a recent example.",
      "Which department or team was involved?",
      "What happened as a result?",
      "How often does this happen?"
    ],
    "recommendation_triggers": [
      "kpi_governance_review",
      "operations_scorecard_design"
    ],
    "roadmap_relevance": "quick_win",
    "finding_strength": "low"
  },
  {
    "question_id": "OPS-005",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Process Discovery",
    "question_text": "Which operational processes should be mapped first during this assessment?",
    "response_type": "multiple_choice",
    "options": [
      "Service request intake",
      "Dispatch and scheduling",
      "Field service execution",
      "Inventory replenishment",
      "Warehouse picking/receiving",
      "Customer complaint handling",
      "Billing handoff",
      "Branch reporting",
      "Procurement approvals",
      "Retreading workflow",
      "Other"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "service_delivery",
    "assessment_category": "process",
    "problem_types_detectable": [
      "bottleneck",
      "manual_process",
      "process_complexity",
      "lack_of_standardization"
    ],
    "impact_dimensions": [
      "time_impact",
      "cost_impact",
      "customer_impact",
      "employee_impact"
    ],
    "maturity_dimensions": [
      "Operations",
      "Automation"
    ],
    "kpi_outputs": [
      "priority_process_inventory"
    ],
    "ai_analysis_purpose": "Create the initial process inventory and identify high-value workflows for assessment.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which selected process creates the most delays?",
      "Which selected process has the highest business impact?",
      "Please provide a recent example.",
      "Which department or team was involved?",
      "What happened as a result?",
      "How often does this happen?"
    ],
    "recommendation_triggers": [
      "process_mapping_workshop",
      "workflow_standardization"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "medium"
  },
  {
    "question_id": "OPS-006",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Process Discovery",
    "question_text": "How standardized are operational processes across branches or teams?",
    "response_type": "scale_1_5",
    "options": [
      "1 = Different everywhere",
      "2 = Mostly informal",
      "3 = Partially standardized",
      "4 = Mostly standardized",
      "5 = Fully standardized and audited"
    ],
    "required": true,
    "score_mapping": {
      "1": 5,
      "2": 4,
      "3": 3,
      "4": 2,
      "5": 1
    },
    "business_domain": "branch_operations",
    "assessment_category": "process",
    "problem_types_detectable": [
      "lack_of_standardization",
      "rework",
      "service_quality_issue"
    ],
    "impact_dimensions": [
      "cost_impact",
      "customer_impact",
      "risk_impact"
    ],
    "maturity_dimensions": [
      "Operations",
      "Customer Experience"
    ],
    "kpi_outputs": [
      "process_standardization_score"
    ],
    "ai_analysis_purpose": "Measure process standardization maturity across operational locations or teams.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which branches or teams work differently?",
      "What problems are caused by inconsistent execution?"
    ],
    "recommendation_triggers": [
      "standard_operating_procedures",
      "branch_operating_model"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-007",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Process Discovery",
    "question_text": "Approximately how many key operational processes depend on a specific employee's personal knowledge?",
    "response_type": "numeric",
    "options": [],
    "required": true,
    "score_mapping": {},
    "business_domain": "risk_management",
    "assessment_category": "people",
    "problem_types_detectable": [
      "knowledge_dependency",
      "business_continuity_risk",
      "unclear_ownership"
    ],
    "impact_dimensions": [
      "risk_impact",
      "employee_impact",
      "time_impact"
    ],
    "maturity_dimensions": [
      "Operations",
      "Risk Management"
    ],
    "kpi_outputs": [
      "critical_process_dependency_count"
    ],
    "ai_analysis_purpose": "Quantify operational knowledge dependency and business continuity exposure.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which processes are most dependent on one person?",
      "What happens if that person is unavailable?"
    ],
    "recommendation_triggers": [
      "process_documentation_program",
      "knowledge_transfer_plan"
    ],
    "roadmap_relevance": "quick_win",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-008",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Bottlenecks & Delays",
    "question_text": "Where do operational delays occur most frequently?",
    "response_type": "multiple_choice",
    "options": [
      "Customer request intake",
      "Missing customer information",
      "Approval waiting",
      "Technician assignment",
      "Inventory availability",
      "Warehouse picking",
      "Transportation/logistics",
      "Service completion reporting",
      "Billing handoff",
      "Management reporting",
      "Other"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "service_delivery",
    "assessment_category": "process",
    "problem_types_detectable": [
      "bottleneck",
      "approval_delay",
      "missing_data",
      "communication_breakdown"
    ],
    "impact_dimensions": [
      "time_impact",
      "customer_impact",
      "employee_impact"
    ],
    "maturity_dimensions": [
      "Operations",
      "Customer Experience"
    ],
    "kpi_outputs": [
      "delay_location_frequency"
    ],
    "ai_analysis_purpose": "Locate operational delay points and connect them to process, data, or communication root causes.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which delay occurs daily?",
      "Which delay creates the greatest customer impact?",
      "Please provide a recent example.",
      "Which department or team was involved?",
      "What happened as a result?",
      "How often does this happen?",
      "Frequency: Rarely / Monthly / Weekly / Daily / Continuously.",
      "Severity: Rate the business severity from 1 = Minor to 5 = Critical.",
      "Business impact: Which dimensions are affected most? Time / Cost / Customer / Risk / Employee."
    ],
    "recommendation_triggers": [
      "bottleneck_removal",
      "service_flow_redesign"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "medium"
  },
  {
    "question_id": "OPS-009",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Bottlenecks & Delays",
    "question_text": "What is the average delay caused by approvals in critical operational workflows?",
    "response_type": "time_duration",
    "options": [
      "No meaningful delay",
      "Less than 15 minutes",
      "15-30 minutes",
      "30-60 minutes",
      "1-4 hours",
      "Same day",
      "More than 1 day",
      "Unknown"
    ],
    "required": true,
    "score_mapping": {
      "No meaningful delay": 1,
      "Less than 15 minutes": 1,
      "15-30 minutes": 2,
      "30-60 minutes": 3,
      "1-4 hours": 4,
      "Same day": 4,
      "More than 1 day": 5,
      "Unknown": 4
    },
    "business_domain": "governance",
    "assessment_category": "process",
    "problem_types_detectable": [
      "approval_delay",
      "bottleneck",
      "process_complexity"
    ],
    "impact_dimensions": [
      "time_impact",
      "cost_impact",
      "customer_impact"
    ],
    "maturity_dimensions": [
      "Operations",
      "Automation"
    ],
    "kpi_outputs": [
      "approval_cycle_time",
      "approval_delay_gap"
    ],
    "ai_analysis_purpose": "Estimate approval-related delay and determine whether approval automation is justified.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which approvals create the longest delay?",
      "Are approval rules documented?",
      "Can any approvals be automated or delegated?",
      "What would be an acceptable target approval delay for critical workflows?",
      "Calculate approval_delay_gap = current approval delay - target approval delay."
    ],
    "recommendation_triggers": [
      "approval_workflow_automation",
      "delegation_matrix"
    ],
    "roadmap_relevance": "quick_win",
    "gap_analysis": {
      "current_state_value": "current_approval_delay",
      "desired_state_value": "target_approval_delay",
      "gap_value": "approval_delay_gap = current_approval_delay - target_approval_delay",
      "improvement_potential": "Quantifies time reduction potential from approval redesign, delegation, or automation."
    },
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-010",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Bottlenecks & Delays",
    "question_text": "What percentage of operational work requires rework or correction?",
    "response_type": "percentage",
    "options": [],
    "required": true,
    "score_mapping": {},
    "business_domain": "service_delivery",
    "assessment_category": "process",
    "problem_types_detectable": [
      "rework",
      "inaccurate_data",
      "service_quality_issue",
      "training_gap"
    ],
    "impact_dimensions": [
      "cost_impact",
      "time_impact",
      "employee_impact",
      "customer_impact"
    ],
    "maturity_dimensions": [
      "Operations",
      "Customer Experience"
    ],
    "kpi_outputs": [
      "rework_rate"
    ],
    "ai_analysis_purpose": "Quantify rework exposure and identify quality, data, or training root causes.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "What causes most rework?",
      "Which teams or processes are most affected?",
      "How is rework tracked today?",
      "Frequency: Rarely / Monthly / Weekly / Daily / Continuously.",
      "Severity: Rate the business severity from 1 = Minor to 5 = Critical.",
      "Business impact: Which dimensions are affected most? Time / Cost / Customer / Risk / Employee."
    ],
    "recommendation_triggers": [
      "quality_control_checkpoints",
      "training_program",
      "data_validation_rules"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-011",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Data & Reporting",
    "question_text": "How much time does your team spend preparing recurring operational reports each week?",
    "response_type": "numeric",
    "options": [],
    "required": true,
    "score_mapping": {},
    "business_domain": "reporting_analytics",
    "assessment_category": "reporting",
    "problem_types_detectable": [
      "manual_process",
      "spreadsheet_dependency",
      "reporting_gap",
      "duplicate_activity"
    ],
    "impact_dimensions": [
      "time_impact",
      "cost_impact",
      "employee_impact"
    ],
    "maturity_dimensions": [
      "Analytics",
      "Automation",
      "Operations"
    ],
    "kpi_outputs": [
      "report_preparation_time",
      "hours_lost_to_manual_work",
      "reporting_time_gap"
    ],
    "ai_analysis_purpose": "Quantify reporting burden and identify reporting automation opportunities.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which reports take the longest?",
      "Which reports are built manually?",
      "Who consumes these reports?",
      "What would be an acceptable target time per week for preparing these reports?",
      "Calculate reporting_time_gap = current weekly reporting hours - target weekly reporting hours."
    ],
    "recommendation_triggers": [
      "automated_reporting",
      "kpi_dashboard",
      "single_source_reporting_layer"
    ],
    "roadmap_relevance": "quick_win",
    "gap_analysis": {
      "current_state_value": "current_report_preparation_hours_per_week",
      "desired_state_value": "target_report_preparation_hours_per_week",
      "gap_value": "reporting_time_gap = current_report_preparation_hours_per_week - target_report_preparation_hours_per_week",
      "improvement_potential": "Quantifies weekly hours that could be recovered through reporting automation and dashboarding."
    },
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-012",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Data & Reporting",
    "question_text": "How reliable is the operational data used for management decisions?",
    "response_type": "scale_1_5",
    "options": [
      "1 = Not reliable",
      "2 = Often disputed",
      "3 = Sometimes reliable",
      "4 = Mostly reliable",
      "5 = Reliable and trusted"
    ],
    "required": true,
    "score_mapping": {
      "1": 5,
      "2": 4,
      "3": 3,
      "4": 2,
      "5": 1
    },
    "business_domain": "data_management",
    "assessment_category": "data",
    "problem_types_detectable": [
      "inaccurate_data",
      "missing_data",
      "no_single_source_of_truth",
      "data_silo"
    ],
    "impact_dimensions": [
      "risk_impact",
      "cost_impact",
      "revenue_impact"
    ],
    "maturity_dimensions": [
      "Data",
      "Analytics"
    ],
    "kpi_outputs": [
      "data_accuracy_rate",
      "single_source_of_truth_score"
    ],
    "ai_analysis_purpose": "Assess trust in operational data and detect data governance gaps.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which data is most often disputed?",
      "What causes data inaccuracies?",
      "Who owns correction of inaccurate data?"
    ],
    "recommendation_triggers": [
      "data_governance_model",
      "master_data_cleanup",
      "source_of_truth_definition"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-013",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Data & Reporting",
    "question_text": "Which KPIs are currently unavailable but important for operations?",
    "response_type": "multiple_choice",
    "options": [
      "Average dispatch time",
      "Response time",
      "Service completion time",
      "First-time resolution rate",
      "Rework rate",
      "Inventory accuracy",
      "Stockout rate",
      "Technician utilization",
      "Customer downtime",
      "Cost per service",
      "SLA compliance",
      "Other"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "reporting_analytics",
    "assessment_category": "reporting",
    "problem_types_detectable": [
      "reporting_gap",
      "missing_data",
      "no_single_source_of_truth"
    ],
    "impact_dimensions": [
      "time_impact",
      "customer_impact",
      "risk_impact"
    ],
    "maturity_dimensions": [
      "Analytics",
      "Data",
      "Operations"
    ],
    "kpi_outputs": [
      "missing_operations_kpis"
    ],
    "ai_analysis_purpose": "Identify KPI gaps that should feed Layer 13 KPI discovery and measurement planning.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which missing KPI would change decision-making most?",
      "What data is needed to calculate it?",
      "Is any estimate available today?",
      "Please provide a recent example.",
      "Which department or team was involved?",
      "What happened as a result?",
      "How often does this happen?"
    ],
    "recommendation_triggers": [
      "kpi_gap_report",
      "data_capture_plan",
      "operations_dashboard"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "medium"
  },
  {
    "question_id": "OPS-014",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Technology & Systems",
    "question_text": "How many systems or tools are required to complete a typical service request from intake to completion?",
    "response_type": "single_choice",
    "options": [
      "1 system",
      "2 systems",
      "3 systems",
      "4-5 systems",
      "6+ systems",
      "Unknown"
    ],
    "required": true,
    "score_mapping": {
      "1 system": 1,
      "2 systems": 2,
      "3 systems": 3,
      "4-5 systems": 4,
      "6+ systems": 5,
      "Unknown": 4
    },
    "business_domain": "technology",
    "assessment_category": "technology",
    "problem_types_detectable": [
      "missing_integration",
      "duplicate_activity",
      "process_complexity",
      "poor_usability"
    ],
    "impact_dimensions": [
      "time_impact",
      "employee_impact",
      "risk_impact"
    ],
    "maturity_dimensions": [
      "Technology",
      "Automation"
    ],
    "kpi_outputs": [
      "systems_per_service_request",
      "system_complexity_gap"
    ],
    "ai_analysis_purpose": "Measure system fragmentation in service delivery and identify integration opportunities.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which systems are involved?",
      "Where is data entered more than once?",
      "Which system creates the most friction?",
      "What would be the desired number of systems for a typical service request?",
      "Calculate system_complexity_gap = current system count - target system count."
    ],
    "recommendation_triggers": [
      "system_integration_assessment",
      "workflow_orchestration"
    ],
    "roadmap_relevance": "foundation",
    "gap_analysis": {
      "current_state_value": "current_system_count_per_service_request",
      "desired_state_value": "target_system_count_per_service_request",
      "gap_value": "system_complexity_gap = current_system_count_per_service_request - target_system_count_per_service_request",
      "improvement_potential": "Quantifies simplification potential from integration, workflow consolidation, or single intake layer."
    },
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-015",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Technology & Systems",
    "question_text": "Which informal tools are used to manage operational work?",
    "response_type": "multiple_choice",
    "options": [
      "WhatsApp",
      "Excel/Spreadsheets",
      "Paper forms",
      "Phone calls",
      "Personal notebooks",
      "Email chains",
      "Shared drives",
      "None",
      "Other"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "technology",
    "assessment_category": "communication",
    "problem_types_detectable": [
      "whatsapp_dependency",
      "spreadsheet_dependency",
      "paper_based_process",
      "communication_breakdown",
      "missing_integration"
    ],
    "impact_dimensions": [
      "time_impact",
      "risk_impact",
      "employee_impact",
      "customer_impact"
    ],
    "maturity_dimensions": [
      "Technology",
      "Automation",
      "Data"
    ],
    "kpi_outputs": [
      "shadow_tool_dependency"
    ],
    "ai_analysis_purpose": "Detect shadow tools and informal coordination patterns that create data and visibility gaps.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which informal tool is most critical?",
      "What operational data exists only in informal tools?",
      "What would break if this tool disappeared?",
      "Please provide a recent example.",
      "Which department or team was involved?",
      "What happened as a result?",
      "How often does this happen?",
      "Frequency: Rarely / Monthly / Weekly / Daily / Continuously.",
      "Severity: Rate the business severity from 1 = Minor to 5 = Critical.",
      "Business impact: Which dimensions are affected most? Time / Cost / Customer / Risk / Employee."
    ],
    "recommendation_triggers": [
      "centralized_work_management",
      "digital_forms",
      "communication_standardization"
    ],
    "roadmap_relevance": "quick_win",
    "finding_strength": "medium"
  },
  {
    "question_id": "OPS-016",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Technology & Systems",
    "question_text": "How satisfied are operations users with current systems?",
    "response_type": "scale_1_5",
    "options": [
      "1 = Very dissatisfied",
      "2 = Dissatisfied",
      "3 = Neutral",
      "4 = Satisfied",
      "5 = Very satisfied"
    ],
    "required": true,
    "score_mapping": {
      "1": 5,
      "2": 4,
      "3": 3,
      "4": 2,
      "5": 1
    },
    "business_domain": "technology",
    "assessment_category": "technology",
    "problem_types_detectable": [
      "poor_usability",
      "lack_of_automation",
      "training_gap",
      "manual_process"
    ],
    "impact_dimensions": [
      "employee_impact",
      "time_impact",
      "cost_impact"
    ],
    "maturity_dimensions": [
      "Technology",
      "Workforce"
    ],
    "kpi_outputs": [
      "system_satisfaction_score",
      "system_adoption_risk"
    ],
    "ai_analysis_purpose": "Assess system usability and adoption barriers in operations.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which system causes the most frustration?",
      "What tasks are hardest to complete in current systems?",
      "Is the problem training, usability, or missing functionality?"
    ],
    "recommendation_triggers": [
      "system_usability_review",
      "training_program",
      "workflow_redesign"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-017",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Workforce Productivity",
    "question_text": "What percentage of operational work is manual and repeatable?",
    "response_type": "percentage",
    "options": [],
    "required": true,
    "score_mapping": {},
    "business_domain": "automation",
    "assessment_category": "automation",
    "problem_types_detectable": [
      "manual_process",
      "lack_of_automation",
      "duplicate_activity"
    ],
    "impact_dimensions": [
      "time_impact",
      "cost_impact",
      "employee_impact"
    ],
    "maturity_dimensions": [
      "Automation",
      "Operations"
    ],
    "kpi_outputs": [
      "manual_process_ratio",
      "automation_rate",
      "manual_work_reduction_gap"
    ],
    "ai_analysis_purpose": "Estimate automation potential by quantifying manual repeatable work.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which manual task is repeated most often?",
      "How many people perform it?",
      "What data or approval is needed to automate it?",
      "What would be an acceptable target percentage for manual and repeatable work?",
      "Calculate manual_work_reduction_gap = current manual work percentage - target manual work percentage."
    ],
    "recommendation_triggers": [
      "workflow_automation",
      "digital_forms",
      "process_automation_backlog"
    ],
    "roadmap_relevance": "quick_win",
    "gap_analysis": {
      "current_state_value": "current_manual_repeatable_work_percentage",
      "desired_state_value": "target_manual_repeatable_work_percentage",
      "gap_value": "manual_work_reduction_gap = current_manual_repeatable_work_percentage - target_manual_repeatable_work_percentage",
      "improvement_potential": "Quantifies automation potential across repeatable operational work."
    },
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-018",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Workforce Productivity",
    "question_text": "Where does workload imbalance occur most often?",
    "response_type": "multiple_choice",
    "options": [
      "Dispatch",
      "Customer service",
      "Technicians",
      "Warehouse",
      "Branch managers",
      "Inventory team",
      "Finance handoff",
      "Reporting/admin",
      "No major imbalance",
      "Unknown"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "workforce",
    "assessment_category": "people",
    "problem_types_detectable": [
      "workload_imbalance",
      "resource_shortage",
      "communication_breakdown"
    ],
    "impact_dimensions": [
      "employee_impact",
      "time_impact",
      "customer_impact"
    ],
    "maturity_dimensions": [
      "Workforce",
      "Operations"
    ],
    "kpi_outputs": [
      "workload_imbalance_locations"
    ],
    "ai_analysis_purpose": "Identify workforce capacity pressure points and productivity risks.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "What causes the imbalance?",
      "Is the imbalance seasonal, daily, or continuous?",
      "Which KPI would reveal this problem earlier?",
      "Frequency: Rarely / Monthly / Weekly / Daily / Continuously.",
      "Severity: Rate the business severity from 1 = Minor to 5 = Critical.",
      "Business impact: Which dimensions are affected most? Time / Cost / Customer / Risk / Employee."
    ],
    "recommendation_triggers": [
      "capacity_planning",
      "workload_dashboard",
      "role_redesign"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "medium"
  },
  {
    "question_id": "OPS-019",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Workforce Productivity",
    "question_text": "How many hours per week are lost because employees search for missing information?",
    "response_type": "numeric",
    "options": [],
    "required": true,
    "score_mapping": {},
    "business_domain": "data_management",
    "assessment_category": "data",
    "problem_types_detectable": [
      "missing_data",
      "data_silo",
      "communication_breakdown",
      "no_single_source_of_truth"
    ],
    "impact_dimensions": [
      "time_impact",
      "employee_impact",
      "cost_impact"
    ],
    "maturity_dimensions": [
      "Data",
      "Workforce"
    ],
    "kpi_outputs": [
      "hours_lost_to_missing_information",
      "information_search_time_gap"
    ],
    "ai_analysis_purpose": "Quantify productivity loss caused by missing or hard-to-access operational information.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "What information is searched for most often?",
      "Where should this information exist?",
      "Who usually has to provide it?",
      "What would be an acceptable target number of hours lost per week?",
      "Calculate information_search_time_gap = current search hours lost - target search hours lost."
    ],
    "recommendation_triggers": [
      "single_source_of_truth",
      "operational_knowledge_base",
      "data_access_improvement"
    ],
    "roadmap_relevance": "quick_win",
    "gap_analysis": {
      "current_state_value": "current_hours_lost_searching_per_week",
      "desired_state_value": "target_hours_lost_searching_per_week",
      "gap_value": "information_search_time_gap = current_hours_lost_searching_per_week - target_hours_lost_searching_per_week",
      "improvement_potential": "Quantifies productivity gain from better data availability, ownership, and searchability."
    },
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-020",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Customer Impact",
    "question_text": "Which operational issues most often affect customers?",
    "response_type": "multiple_choice",
    "options": [
      "Slow response time",
      "Unclear service status",
      "Missed appointment or delay",
      "Incomplete service information",
      "Repeat visits",
      "Inventory not available",
      "Billing delay",
      "Poor complaint follow-up",
      "Inconsistent service quality",
      "Other"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "customer_experience",
    "assessment_category": "customer",
    "problem_types_detectable": [
      "slow_response_time",
      "poor_service_visibility",
      "customer_complaints",
      "service_quality_issue",
      "billing_delay"
    ],
    "impact_dimensions": [
      "customer_impact",
      "revenue_impact",
      "risk_impact"
    ],
    "maturity_dimensions": [
      "Customer Experience",
      "Operations"
    ],
    "kpi_outputs": [
      "customer_impact_issue_frequency"
    ],
    "ai_analysis_purpose": "Connect operational problems to customer-facing pain points and retention risk.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which issue creates the most complaints?",
      "Which issue creates the most revenue risk?",
      "How is customer impact measured today?",
      "Please provide a recent example.",
      "Which department or team was involved?",
      "What happened as a result?",
      "How often does this happen?",
      "Frequency: Rarely / Monthly / Weekly / Daily / Continuously.",
      "Severity: Rate the business severity from 1 = Minor to 5 = Critical.",
      "Business impact: Which dimensions are affected most? Time / Cost / Customer / Risk / Employee."
    ],
    "recommendation_triggers": [
      "customer_visibility_portal",
      "service_status_tracking",
      "complaint_management_process"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "medium"
  },
  {
    "question_id": "OPS-021",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Customer Impact",
    "question_text": "How often do customers ask for service status or follow-up information?",
    "response_type": "single_choice",
    "options": [
      "Rarely",
      "Monthly",
      "Weekly",
      "Daily",
      "Continuously",
      "Unknown"
    ],
    "required": true,
    "score_mapping": {
      "Rarely": 1,
      "Monthly": 2,
      "Weekly": 3,
      "Daily": 4,
      "Continuously": 5,
      "Unknown": 3
    },
    "business_domain": "customer_experience",
    "assessment_category": "customer",
    "problem_types_detectable": [
      "poor_service_visibility",
      "slow_response_time",
      "communication_breakdown"
    ],
    "impact_dimensions": [
      "customer_impact",
      "employee_impact",
      "time_impact"
    ],
    "maturity_dimensions": [
      "Customer Experience",
      "Technology"
    ],
    "kpi_outputs": [
      "customer_status_request_frequency",
      "customer_visibility_gap"
    ],
    "ai_analysis_purpose": "Determine whether lack of service visibility creates customer and employee workload.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "What information do customers ask for most?",
      "Who answers these requests?",
      "Can this information be self-served digitally?",
      "What would be an acceptable target frequency for customers needing to ask for status manually?",
      "Calculate customer_visibility_gap = current request frequency - target request frequency."
    ],
    "recommendation_triggers": [
      "customer_portal",
      "service_tracking_notifications",
      "customer_status_dashboard"
    ],
    "roadmap_relevance": "optimization",
    "gap_analysis": {
      "current_state_value": "current_customer_status_request_frequency",
      "desired_state_value": "target_customer_status_request_frequency",
      "gap_value": "customer_visibility_gap = current_customer_status_request_frequency - target_customer_status_request_frequency",
      "improvement_potential": "Quantifies potential reduction in reactive customer follow-up through portals, notifications, or tracking visibility."
    },
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-022",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Risk & Continuity",
    "question_text": "Which operational risks are most concerning today?",
    "response_type": "multiple_choice",
    "options": [
      "Key person dependency",
      "System outage",
      "Inventory shortage",
      "Supplier delay",
      "Service partner performance",
      "Compliance/documentation gap",
      "Customer SLA failure",
      "Data loss or inaccurate data",
      "Branch disruption",
      "No major risk",
      "Other"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "risk_management",
    "assessment_category": "risk",
    "problem_types_detectable": [
      "operational_risk",
      "technology_risk",
      "business_continuity_risk",
      "missing_data"
    ],
    "impact_dimensions": [
      "risk_impact",
      "customer_impact",
      "revenue_impact",
      "cost_impact"
    ],
    "maturity_dimensions": [
      "Risk Management",
      "Operations"
    ],
    "kpi_outputs": [
      "top_operational_risks"
    ],
    "ai_analysis_purpose": "Identify current operational risk profile and business continuity concerns.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which risk could stop operations?",
      "Is there a documented contingency plan?",
      "How often is this risk reviewed?",
      "Please provide a recent example.",
      "Which department or team was involved?",
      "What happened as a result?",
      "How often does this happen?",
      "Frequency: Rarely / Monthly / Weekly / Daily / Continuously.",
      "Severity: Rate the business severity from 1 = Minor to 5 = Critical.",
      "Business impact: Which dimensions are affected most? Time / Cost / Customer / Risk / Employee."
    ],
    "recommendation_triggers": [
      "risk_register",
      "business_continuity_plan",
      "operational_controls"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "medium"
  },
  {
    "question_id": "OPS-023",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Risk & Continuity",
    "question_text": "How prepared is operations to continue work if a core system is unavailable?",
    "response_type": "scale_1_5",
    "options": [
      "1 = Not prepared",
      "2 = Informal workaround only",
      "3 = Partial backup process",
      "4 = Documented backup process",
      "5 = Tested continuity plan"
    ],
    "required": true,
    "score_mapping": {
      "1": 5,
      "2": 4,
      "3": 3,
      "4": 2,
      "5": 1
    },
    "business_domain": "risk_management",
    "assessment_category": "risk",
    "problem_types_detectable": [
      "technology_risk",
      "business_continuity_risk",
      "paper_based_process",
      "knowledge_dependency"
    ],
    "impact_dimensions": [
      "risk_impact",
      "customer_impact",
      "revenue_impact"
    ],
    "maturity_dimensions": [
      "Risk Management",
      "Technology"
    ],
    "kpi_outputs": [
      "system_continuity_readiness_score"
    ],
    "ai_analysis_purpose": "Assess business continuity maturity for system dependency in operations.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Which system is most critical?",
      "How long can operations continue without it?",
      "When was the backup process last tested?"
    ],
    "recommendation_triggers": [
      "continuity_plan",
      "system_dependency_assessment",
      "backup_process_testing"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-024",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Transformation Opportunities",
    "question_text": "Which operational improvements would create the highest value if implemented first?",
    "response_type": "ranking",
    "options": [
      "Digital service request intake",
      "Dispatch automation",
      "Technician mobile forms",
      "Inventory visibility",
      "Automated reporting",
      "Customer service tracking",
      "Branch KPI dashboard",
      "Approval workflow automation",
      "System integration",
      "Workforce planning dashboard"
    ],
    "required": true,
    "score_mapping": {},
    "business_domain": "automation",
    "assessment_category": "automation",
    "problem_types_detectable": [
      "manual_process",
      "lack_of_automation",
      "missing_integration",
      "reporting_gap"
    ],
    "impact_dimensions": [
      "time_impact",
      "cost_impact",
      "customer_impact",
      "employee_impact"
    ],
    "maturity_dimensions": [
      "Automation",
      "Technology",
      "Operations"
    ],
    "kpi_outputs": [
      "operations_transformation_priority_rankings"
    ],
    "ai_analysis_purpose": "Prioritize transformation initiatives based on operational value perception.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "Why is the first-ranked improvement most valuable?",
      "What would need to change before implementation?",
      "Which KPI would prove success?"
    ],
    "recommendation_triggers": [
      "opportunity_matrix",
      "quick_win_identification",
      "operations_transformation_roadmap"
    ],
    "roadmap_relevance": "foundation",
    "finding_strength": "high"
  },
  {
    "question_id": "OPS-025",
    "stakeholder_group": "Operations",
    "stakeholder_role": "Operations Manager",
    "section": "Transformation Opportunities",
    "question_text": "If you could digitize one operational workflow in the next 90 days, which one would it be and why?",
    "response_type": "open_text",
    "options": [],
    "required": true,
    "score_mapping": {},
    "business_domain": "automation",
    "assessment_category": "automation",
    "problem_types_detectable": [
      "manual_process",
      "lack_of_automation",
      "bottleneck",
      "duplicate_activity",
      "communication_breakdown"
    ],
    "impact_dimensions": [
      "time_impact",
      "cost_impact",
      "customer_impact",
      "employee_impact"
    ],
    "maturity_dimensions": [
      "Automation",
      "Innovation",
      "Operations"
    ],
    "kpi_outputs": [
      "candidate_quick_win_workflow"
    ],
    "ai_analysis_purpose": "Capture the Operations Manager's highest-confidence quick-win digitization opportunity.",
    "follow_up_enabled": true,
    "follow_up_questions": [
      "What problem would this solve?",
      "Who would benefit most?",
      "What data would need to be captured?",
      "What would success look like after 90 days?",
      "Please provide a recent example.",
      "Which department or team was involved?",
      "What happened as a result?",
      "How often does this happen?"
    ],
    "recommendation_triggers": [
      "quick_win_digital_workflow",
      "pilot_project_definition",
      "roadmap_phase_1_candidate"
    ],
    "roadmap_relevance": "quick_win",
    "finding_strength": "low"
  }
]

let dispatcherQuestionBankV1 = [];
let technicianQuestionBankV1 = [];
let branchManagerQuestionBankV1 = [];
let warehouseInventoryQuestionBankV1 = [];
let financeManagerQuestionBankV1 = [];
let salesManagerQuestionBankV1 = [];
let customerAssessmentV1 = [];
let servicePartnerAssessmentV1 = [];
let supplierAssessmentV1 = [];
let itSystemsAssessmentV1 = [];
let hrWorkforceAssessmentV1 = [];

const questionBankRoles = [
  { group: "Executive", groupId: "executive", role: "Owner", roleId: "owner", key: "owner", version: "pending", questions: [] },
  { group: "Executive", groupId: "executive", role: "CEO / Managing Director", roleId: "ceo", key: "ceo", version: "pending", questions: [] },
  { group: "Management", groupId: "management", role: "Operations Manager", roleId: "operations_manager", key: "operations-manager", version: "v1", questions: operationsManagerQuestionBankV1 },
  { group: "Management", groupId: "management", role: "Branch Manager", roleId: "branch_manager", key: "branch-manager", version: "pending", questions: branchManagerQuestionBankV1 },
  { group: "Operations", groupId: "operations", role: "Dispatcher / Customer Service Coordinator", roleId: "dispatcher", key: "dispatcher", version: "v1", questions: dispatcherQuestionBankV1 },
  { group: "Operations", groupId: "operations", role: "Technician / Field Service Technician", roleId: "technician", key: "technician", version: "v1", questions: technicianQuestionBankV1 },
  { group: "Operations", groupId: "operations", role: "Warehouse Manager", roleId: "warehouse_manager", key: "warehouse-manager", version: "pending", questions: warehouseInventoryQuestionBankV1 },
  { group: "Operations", groupId: "operations", role: "Inventory Coordinator", roleId: "inventory_coordinator", key: "inventory-coordinator", version: "pending", questions: warehouseInventoryQuestionBankV1 },
  { group: "Support Functions", groupId: "support_functions", role: "Finance Manager", roleId: "finance_manager", key: "finance-manager", version: "pending", questions: financeManagerQuestionBankV1 },
  { group: "Support Functions", groupId: "support_functions", role: "Accountant", roleId: "accountant", key: "accountant", version: "pending", questions: [] },
  { group: "Support Functions", groupId: "support_functions", role: "IT Manager / Systems Administrator", roleId: "it_manager", key: "it-manager", version: "pending", questions: itSystemsAssessmentV1 },
  { group: "Support Functions", groupId: "support_functions", role: "HR / Workforce Manager", roleId: "hr_manager", key: "hr-manager", version: "pending", questions: hrWorkforceAssessmentV1 },
  { group: "Commercial", groupId: "commercial", role: "Sales Manager", roleId: "sales_manager", key: "sales-manager", version: "v1", questions: salesManagerQuestionBankV1 },
  { group: "Commercial", groupId: "commercial", role: "Sales Representative / Account Manager", roleId: "sales_representative", key: "sales-representative", version: "pending", questions: [] },
  { group: "Customer", groupId: "customer", role: "Fleet Customer", roleId: "fleet_customer", key: "fleet-customer", version: "v1", questions: customerAssessmentV1 },
  { group: "Customer", groupId: "customer", role: "Dealer Customer", roleId: "dealer_customer", key: "dealer-customer", version: "v1", questions: customerAssessmentV1 },
  { group: "Customer", groupId: "customer", role: "Retail Customer", roleId: "retail_customer", key: "retail-customer", version: "v1", questions: customerAssessmentV1 },
  { group: "Partner", groupId: "partner", role: "Service Partner", roleId: "service_partner", key: "service-partner", version: "pending", questions: servicePartnerAssessmentV1 },
  { group: "Partner", groupId: "partner", role: "Dealer Partner", roleId: "dealer_partner", key: "dealer-partner", version: "pending", questions: [] },
  { group: "Partner", groupId: "partner", role: "Supplier", roleId: "supplier", key: "supplier", version: "pending", questions: supplierAssessmentV1 }
];

let activeQuestionBankRole = "operations-manager";

const meetings = [
  {
    title: "Executive Discovery",
    owner: "Owner / General Manager",
    date: "2026-06-05",
    status: "Scheduled"
  },
  {
    title: "Branch Operations Workshop",
    owner: "Branch Managers",
    date: "2026-06-07",
    status: "Scheduled"
  },
  {
    title: "Field Service Workflow Review",
    owner: "Technicians / Dispatch",
    date: "2026-06-10",
    status: "Draft"
  }
];


const meetingAgenda = [
  "Purpose of the digital transformation assessment",
  "Current organization priorities",
  "Main operational pain points",
  "Current systems, reporting, and manual workflows",
  "Assessment process and stakeholder interviews",
  "Next steps and timeline"
];

const OUTLOOK_CLIENT_ID = "ef004f2a-d5fe-41fd-ae24-4b18c578a7a0";
const OUTLOOK_TENANT_ID = "850db4e5-8ef9-4e05-b91c-a19238934fdc";

let responses = [];
let surveyInvites = [];
let projectParticipants = [];
let assessmentProjects = [];
let activeProject = JSON.parse(localStorage.getItem("activeAssessmentProject") || "null");
let activeProjectWorkspaceOpen = localStorage.getItem("activeProjectWorkspaceOpen") === "true";
let activeViewId = "platform-command";
let activeManagerSection = "manager-overview";
let activeAssessmentWorkspaceTab = localStorage.getItem("activeAssessmentWorkspaceTab") || "setup";
let projectContextIntake = null;
let companyProfile = null;
let assessmentEngineState = null;
let executiveReportState = null;
let analysisProgressTimer = null;
let selectedFindingId = localStorage.getItem("selectedFindingId") || "";
let ownerStakeholderGroupFilter = localStorage.getItem("ownerStakeholderGroupFilter") || "";
let ownerStakeholderRoleFilter = localStorage.getItem("ownerStakeholderRoleFilter") || "";
let ownerHeatmapDomainFilter = localStorage.getItem("ownerHeatmapDomainFilter") || "";
let ownerHeatmapGroupFilter = localStorage.getItem("ownerHeatmapGroupFilter") || "";
let ownerHeatmapMinPriority = localStorage.getItem("ownerHeatmapMinPriority") || "0";
let ownerHeatmapOnlyMisalignment = localStorage.getItem("ownerHeatmapOnlyMisalignment") === "true";
let ownerHeatmapOnlyHighConfidence = localStorage.getItem("ownerHeatmapOnlyHighConfidence") === "true";
let selectedHeatmapCellKey = localStorage.getItem("selectedHeatmapCellKey") || "";
let participantRoleFilter = localStorage.getItem("participantRoleFilter") || "";
let participantGroupFilter = localStorage.getItem("participantGroupFilter") || "";
let participantStatusFilter = localStorage.getItem("participantStatusFilter") || "";
const respondPathMatch = location.pathname.match(/^\/respond\/([^/?#]+)/);
const activeRespondToken = respondPathMatch ? decodeURIComponent(respondPathMatch[1]) : "";
let respondentAssessmentState = null;
let respondentSaveTimer = null;
let respondentValidationIssues = { missing_required_questions: [], invalid_answers: [] };
let respondentSaveStatus = "Your answers are saved automatically.";
let respondentLastSavedAt = "";
let participantAccessLinks = JSON.parse(localStorage.getItem("participantAccessLinks") || "{}");
let assessmentParticipantUploadPreview = null;
let assessmentParticipantImportSummary = null;
let assessmentInvitationSummary = null;
let assessmentInvitationPreview = null;
let assessmentReminderSummary = null;
let assessmentReminderPreview = null;
let consultantCommandCenterState = null;
let consultantCommandCenterError = "";
let platformCommandCenterState = null;
let platformCommandCenterError = "";
let platformClassificationFilter = localStorage.getItem("platformClassificationFilter") || "production";
let assessmentManagerCommandCenterState = null;
let assessmentManagerCommandCenterError = "";
let krbOperationsState = null;
let krbOperationsSection = localStorage.getItem("krbOperationsSection") || "overview";
let krbOperationsLoading = false;
let krbOperationsError = "";
let krbOperationsLastRefreshed = "";
let activeContextLanguage = localStorage.getItem("activeContextLanguage") || projectContextIntake?.language || activeProject?.defaultLanguage || "tr";
let stakeholderRoleSaveTimer;
let outlookConfig = {
  clientId: OUTLOOK_CLIENT_ID,
  tenant: OUTLOOK_TENANT_ID,
  ...JSON.parse(localStorage.getItem("krbOutlookConfig") || "{}")
};
if (!outlookConfig.clientId || outlookConfig.tenant === "organizations" || outlookConfig.tenant === "common") {
  outlookConfig.clientId = OUTLOOK_CLIENT_ID;
  outlookConfig.tenant = OUTLOOK_TENANT_ID;
}
let platformUsers = JSON.parse(localStorage.getItem("krbPlatformUsers") || "{}");
if (!platformUsers["fatih@deriveglobal.com"]) {
  platformUsers["fatih@deriveglobal.com"] = {
    name: "Fatih Yildirim",
    email: "fatih@deriveglobal.com",
    role: "platform_owner",
    password: "creator-managed",
    status: "Active",
    createdAt: new Date().toISOString(),
    credentialsSentAt: null
  };
  localStorage.setItem("krbPlatformUsers", JSON.stringify(platformUsers));
}
const urlParams = new URLSearchParams(location.search);
let activeSurveyToken = urlParams.get("survey");
let activeSurveyLanguage = urlParams.get("lang") || "tr";
let activeContextToken = urlParams.get("context");
let activeResetToken = urlParams.get("reset");
let shouldOpenAppShell = urlParams.get("app") === "1" || location.pathname === "/app";
let authMode = "signin";
let publicExplorerLanguage = localStorage.getItem("publicExplorerLanguage") || "en";
let activeExplorerModule = localStorage.getItem("activeExplorerModule") || "company_dna";
let currentUserEmail = localStorage.getItem("krbCurrentUserEmail") || "";
let currentUser = JSON.parse(localStorage.getItem("currentPlatformUser") || "null");
let currentSessionToken = ""; // never persisted to localStorage — lives in memory only; cookie is the auth mechanism
let currentRole = "participant";

const intelligenceExplorerCopy = {
  en: {
    eyebrow: "Platform Architecture",
    heroEyebrow: "Executive Discovery System",
    heroTitle: "Turn field reality into a measurable transformation roadmap.",
    heroCopy: "Collect stakeholder insight, identify operational bottlenecks, synthesize evidence, and prepare owner-ready digital transformation reports.",
    loginButton: "Login",
    proofOne: "Service domains",
    proofTwo: "Assessment dimensions",
    proofThree: "Roadmap horizons",
    title: "Explore the Intelligence Engine",
    subtitle: "See how scattered business input becomes evidence, findings, recommendations, and a roadmap.",
    pulseTitle: "10 modules",
    pulseSubtitle: "from company context to owner decisions",
    labels: {
      what: "What it is",
      why: "Why it matters",
      inputs: "Inputs",
      outputs: "Outputs",
      example: "Example",
      widgets: "Related dashboard widgets",
      owner: "How it helps the owner"
    },
    ctaTitle: "Want to see the full flow?",
    ctaCopy: "Generate a complete demo assessment or open a sample owner dashboard after signing in.",
    ctaDemo: "Generate Demo Assessment",
    ctaDashboard: "View Sample Executive Dashboard",
    signInMessage: "Sign in as creator to generate a demo assessment or open the sample owner dashboard.",
    modules: [
      {
        id: "company_dna",
        title: "Organization Profile",
        summary: "Industry, business model, complexity, and strategic priorities.",
        what: "The platform first understands the company’s industry, business model, activities, operational complexity, and strategic priorities.",
        why: "AI recommendations are only useful when the system understands what kind of business it is analyzing.",
        inputs: ["Industry", "Business activities", "Operational characteristics", "Strategic priorities", "Company size", "Locations", "Workforce structure"],
        outputs: ["Recommended stakeholder roles", "Recommended question banks", "Recommended KPIs", "Context-aware severity scoring", "KPI gap detection"],
        example: "A mobile service company with emergency support should measure dispatch time, response time, SLA compliance, and technician utilization.",
        widgets: ["Organization Profile Panel", "Missing KPI Radar", "Recommended Stakeholders"],
        owner: "It prevents generic recommendations and makes the system evaluate the company based on how it actually operates."
      },
      {
        id: "stakeholder_intelligence",
        title: "Stakeholder Intelligence",
        summary: "Structured input from each role across the organization.",
        what: "The platform collects structured input from different roles across the organization.",
        why: "Owners, managers, dispatchers, technicians, finance teams, customers, and partners each see a different part of reality.",
        inputs: ["Owner responses", "Manager responses", "Branch responses", "Dispatcher responses", "Technician responses", "Finance/customer/partner responses"],
        outputs: ["Cross-role evidence", "Stakeholder agreement", "Misalignment detection", "Confidence scoring"],
        example: "If operations, dispatch, and technicians all mention dispatch delays, the system treats it as a high-confidence issue.",
        widgets: ["Stakeholder Agreement", "Organizational Alignment Heatmap", "Evidence Explorer"],
        owner: "It shows whether issues are isolated opinions or organization-wide patterns."
      },
      {
        id: "evidence_mapping",
        title: "Evidence Mapping",
        summary: "Every insight is traceable to source questions and responses.",
        what: "Every finding is linked back to the original questions, responses, stakeholder roles, and evidence sources.",
        why: "The system does not simply create opinions. Every insight must be traceable.",
        inputs: ["Responses", "Questions", "Stakeholder roles", "Trigger rules"],
        outputs: ["Evidence records", "Evidence count", "Source response links", "Confidence support"],
        example: "A finding like “Missing Information at Request Intake” may be supported by dispatcher, technician, and branch manager responses.",
        widgets: ["Evidence-Backed Insight Panel", "Findings Workbench"],
        owner: "It creates trust. Owners can see exactly why a finding was generated."
      },
      {
        id: "finding_generation",
        title: "Finding Generation",
        summary: "Raw answers become structured business findings.",
        what: "The platform converts raw responses into structured business findings.",
        why: "Answers alone are not useful. Findings explain what is actually wrong or what opportunity exists.",
        inputs: ["Stakeholder responses", "Problem types", "Business domains", "Assessment categories", "KPI signals"],
        outputs: ["Findings", "Severity", "Frequency", "Priority score", "Problem type classification"],
        example: "Multiple answers about WhatsApp, spreadsheets, and duplicate entry become a finding called “Communication and Workflow Fragmentation.”",
        widgets: ["Top Problems", "Operational Hotspots", "Findings Workbench"],
        owner: "It turns scattered comments into clear business issues."
      },
      {
        id: "agreement_engine",
        title: "Agreement Engine",
        summary: "Confidence rises when multiple groups report the same issue.",
        what: "The system measures whether multiple stakeholder groups identify the same issue.",
        why: "When different levels of the organization independently report the same problem, confidence increases.",
        inputs: ["Supporting stakeholder roles", "Supporting stakeholder groups", "Evidence count", "Repeated findings"],
        outputs: ["Role agreement score", "Group agreement score", "Overall agreement score", "Confidence increase"],
        example: "Operations Manager + Dispatcher + Technician all report dispatch delays. Agreement score increases.",
        widgets: ["Stakeholder Agreement", "Organizational Alignment Heatmap", "Top Areas of Agreement"],
        owner: "It shows which issues are strongly supported across the organization."
      },
      {
        id: "contradiction_detection",
        title: "Contradiction Detection",
        summary: "Conflicting views reveal blind spots and misalignment.",
        what: "The platform identifies conflicting views between different stakeholder groups.",
        why: "Misalignment often reveals blind spots.",
        inputs: ["Conflicting responses", "Business domain", "Stakeholder group", "Stakeholder role"],
        outputs: ["Contradiction flag", "Misalignment details", "Conflicting evidence", "Cross-level visibility"],
        example: "Owner says reporting is reliable. Finance says reports contain errors. The system flags Reporting & Analytics misalignment.",
        widgets: ["Top Areas of Misalignment", "Organizational Alignment Heatmap", "Evidence Panel"],
        owner: "It reveals where leadership perception differs from operational reality."
      },
      {
        id: "kpi_gap_detection",
        title: "KPI Gap Detection",
        summary: "The system detects important measurements that are missing.",
        what: "The platform identifies important KPIs the business should measure but currently does not.",
        why: "You cannot improve what you do not measure.",
        inputs: ["Organization Profile", "Business activities", "Operational characteristics", "Existing KPI responses"],
        outputs: ["Missing KPI findings", "Required data points", "Recommended capture method", "KPI coverage score"],
        example: "A roadside service business should measure emergency response time. If it does not, the system creates a missing KPI finding.",
        widgets: ["Missing KPI Radar", "Organization Profile Panel", "Executive Snapshot"],
        owner: "It shows what the business is currently blind to."
      },
      {
        id: "recommendation_engine",
        title: "Recommendation Engine",
        summary: "Approved findings become practical business recommendations.",
        what: "The platform converts approved findings into practical recommendations.",
        why: "The goal is not to collect problems. The goal is to decide what to do next.",
        inputs: ["Findings", "Evidence", "Impact scores", "Company context", "KPI gaps", "Problem types"],
        outputs: ["Recommendations", "Expected benefits", "Effort score", "Business value score", "Risk score"],
        example: "Finding: High Manual Workload. Recommendation: Automate repeatable intake, reporting, or approval workflows.",
        widgets: ["Opportunity Board", "Next Best Action", "Recommendations Review"],
        owner: "It turns diagnosis into action."
      },
      {
        id: "roadmap_generator",
        title: "Roadmap Generator",
        summary: "Recommendations are sequenced into phases.",
        what: "The platform organizes recommendations into a phased improvement roadmap.",
        why: "Owners need sequencing, not a long list of ideas.",
        inputs: ["Approved recommendations", "Priority scores", "Effort scores", "Dependencies", "Business value"],
        outputs: ["Quick Wins", "Foundation", "Optimization", "Transformation"],
        example: "Quick Win: digital forms. Foundation: centralized workflow. Optimization: analytics. Transformation: predictive intelligence.",
        widgets: ["Roadmap View", "Next Best Action"],
        owner: "It shows what to do first, what to build next, and what becomes possible later."
      },
      {
        id: "owner_dashboard",
        title: "Executive Dashboard",
        summary: "The executive command center for decision-ready intelligence.",
        what: "The executive command center where owners see the most important insights.",
        why: "Owners should not have to read every response or analyze every chart.",
        inputs: ["Approved findings", "Approved recommendations", "KPI gaps", "Agreement scores", "Contradictions", "Roadmap items"],
        outputs: ["Business Health Score", "Top Problems", "Missing KPI Radar", "Stakeholder Agreement", "Misalignment", "Opportunity Board", "Roadmap", "Next Best Action"],
        example: "The owner immediately sees: “Missing KPI visibility and dispatch delays are high-priority issues supported by multiple stakeholder groups.”",
        widgets: ["Executive Snapshot", "Executive Dashboard", "Next Best Action"],
        owner: "It gives decision-ready intelligence in minutes."
      }
    ]
  },
  tr: {
    eyebrow: "Platform Mimarisi",
    heroEyebrow: "Yönetici Keşif Sistemi",
    heroTitle: "Saha gerçeğini ölçülebilir dönüşüm yol haritasına çevirin.",
    heroCopy: "Paydaş içgörülerini toplayın, operasyonel darboğazları belirleyin, kanıtları sentezleyin ve şirket sahibine hazır dönüşüm raporları üretin.",
    loginButton: "Giriş",
    proofOne: "Servis alanı",
    proofTwo: "Assessment boyutu",
    proofThree: "Yol haritası ufku",
    title: "Zeka Motorunu Keşfedin",
    subtitle: "Dağınık iş bilgisinin nasıl kanıta, bulguya, öneriye ve yol haritasına dönüştüğünü görün.",
    pulseTitle: "10 modül",
    pulseSubtitle: "şirket bağlamından sahip kararlarına",
    labels: {
      what: "Nedir",
      why: "Neden önemli",
      inputs: "Girdiler",
      outputs: "Çıktılar",
      example: "Örnek",
      widgets: "İlgili dashboard alanları",
      owner: "Şirket sahibine faydası"
    },
    ctaTitle: "Tüm akışı görmek ister misiniz?",
    ctaCopy: "Giriş yaptıktan sonra eksiksiz demo assessment oluşturabilir veya örnek sahip dashboard’unu açabilirsiniz.",
    ctaDemo: "Demo Assessment Oluştur",
    ctaDashboard: "Örnek Sahip Dashboard’unu Gör",
    signInMessage: "Demo assessment oluşturmak veya örnek sahip dashboard’unu açmak için creator hesabıyla giriş yapın.",
    modules: [
      {
        id: "company_dna",
        title: "Şirket DNA’sı",
        summary: "Sektör, iş modeli, operasyonel karmaşıklık ve stratejik öncelikler.",
        what: "Platform önce şirketin sektörünü, iş modelini, faaliyetlerini, operasyonel karmaşıklığını ve stratejik önceliklerini anlar.",
        why: "AI önerileri ancak sistem hangi tür işletmeyi analiz ettiğini anlarsa değerli olur.",
        inputs: ["Sektör", "İş faaliyetleri", "Operasyonel özellikler", "Stratejik öncelikler", "Şirket büyüklüğü", "Lokasyonlar", "İşgücü yapısı"],
        outputs: ["Önerilen paydaş rolleri", "Önerilen soru bankaları", "Önerilen KPI’lar", "Bağlama duyarlı önem skoru", "KPI boşluk tespiti"],
        example: "Acil destek veren mobil servis şirketi; dispatch süresi, yanıt süresi, SLA uyumu ve teknisyen kullanım oranını ölçmelidir.",
        widgets: ["Şirket DNA Paneli", "Eksik KPI Radarı", "Önerilen Paydaşlar"],
        owner: "Genel geçer önerileri engeller ve sistemi şirketin gerçekten nasıl çalıştığına göre değerlendirme yapmaya zorlar."
      },
      {
        id: "stakeholder_intelligence",
        title: "Paydaş Zekası",
        summary: "Organizasyonun farklı rollerinden yapılandırılmış bilgi toplar.",
        what: "Platform organizasyondaki farklı rollerden yapılandırılmış girdi toplar.",
        why: "Sahipler, yöneticiler, dispatch ekipleri, teknisyenler, finans, müşteriler ve iş ortakları gerçeğin farklı parçalarını görür.",
        inputs: ["Sahip yanıtları", "Yönetici yanıtları", "Şube yanıtları", "Dispatcher yanıtları", "Teknisyen yanıtları", "Finans/müşteri/partner yanıtları"],
        outputs: ["Roller arası kanıt", "Paydaş mutabakatı", "Uyumsuzluk tespiti", "Güven skoru"],
        example: "Operasyon, dispatch ve teknisyenler dispatch gecikmesini birlikte bildirirse sistem bunu yüksek güvenli sorun olarak ele alır.",
        widgets: ["Paydaş Mutabakatı", "Organizasyonel Hizalanma Haritası", "Kanıt Gezgini"],
        owner: "Sorunların tekil görüş mü yoksa organizasyon geneline yayılan örüntü mü olduğunu gösterir."
      },
      {
        id: "evidence_mapping",
        title: "Kanıt Haritalama",
        summary: "Her içgörü kaynak soru ve yanıtlara geri bağlanır.",
        what: "Her bulgu; orijinal sorulara, yanıtlara, paydaş rollerine ve kanıt kaynaklarına bağlanır.",
        why: "Sistem yalnızca görüş üretmez. Her içgörü izlenebilir olmak zorundadır.",
        inputs: ["Yanıtlar", "Sorular", "Paydaş rolleri", "Tetikleme kuralları"],
        outputs: ["Kanıt kayıtları", "Kanıt sayısı", "Kaynak yanıt bağlantıları", "Güven desteği"],
        example: "“Talep girişinde eksik bilgi” bulgusu dispatcher, teknisyen ve şube müdürü yanıtlarıyla desteklenebilir.",
        widgets: ["Kanıta Dayalı İçgörü Paneli", "Bulgular Workbench"],
        owner: "Güven oluşturur. Şirket sahibi bir bulgunun neden üretildiğini görebilir."
      },
      {
        id: "finding_generation",
        title: "Bulgu Üretimi",
        summary: "Ham yanıtlar yapılandırılmış iş bulgularına dönüşür.",
        what: "Platform ham yanıtları yapılandırılmış iş bulgularına dönüştürür.",
        why: "Yanıtlar tek başına yeterli değildir. Bulgular gerçekte neyin yanlış olduğunu veya hangi fırsatın bulunduğunu açıklar.",
        inputs: ["Paydaş yanıtları", "Problem tipleri", "İş alanları", "Assessment kategorileri", "KPI sinyalleri"],
        outputs: ["Bulgular", "Şiddet", "Frekans", "Öncelik skoru", "Problem tipi sınıflandırması"],
        example: "WhatsApp, Excel ve çift veri girişiyle ilgili yanıtlar “İletişim ve İş Akışı Parçalanması” bulgusuna dönüşebilir.",
        widgets: ["En Önemli Problemler", "Operasyonel Sıcak Noktalar", "Bulgular Workbench"],
        owner: "Dağınık yorumları net iş problemlerine dönüştürür."
      },
      {
        id: "agreement_engine",
        title: "Mutabakat Motoru",
        summary: "Birden fazla grup aynı sorunu bildirirse güven artar.",
        what: "Sistem birden fazla paydaş grubunun aynı sorunu tespit edip etmediğini ölçer.",
        why: "Organizasyonun farklı seviyeleri aynı problemi bağımsız olarak bildirirse güven artar.",
        inputs: ["Destekleyen roller", "Destekleyen gruplar", "Kanıt sayısı", "Tekrarlanan bulgular"],
        outputs: ["Rol mutabakat skoru", "Grup mutabakat skoru", "Genel mutabakat skoru", "Güven artışı"],
        example: "Operasyon Müdürü + Dispatcher + Teknisyen dispatch gecikmesini bildirirse mutabakat skoru artar.",
        widgets: ["Paydaş Mutabakatı", "Organizasyonel Hizalanma Haritası", "En Güçlü Mutabakat Alanları"],
        owner: "Hangi sorunların organizasyon genelinde güçlü destek gördüğünü gösterir."
      },
      {
        id: "contradiction_detection",
        title: "Çelişki Tespiti",
        summary: "Çakışan görüşler kör noktaları ortaya çıkarır.",
        what: "Platform farklı paydaş grupları arasındaki çakışan görüşleri tespit eder.",
        why: "Uyumsuzluk çoğu zaman yönetim kör noktalarını gösterir.",
        inputs: ["Çelişen yanıtlar", "İş alanı", "Paydaş grubu", "Paydaş rolü"],
        outputs: ["Çelişki bayrağı", "Uyumsuzluk detayları", "Çelişen kanıtlar", "Seviyeler arası görünürlük"],
        example: "Sahip raporlama güvenilir diyor. Finans raporlarda hata olduğunu söylüyor. Sistem Reporting & Analytics uyumsuzluğunu işaretler.",
        widgets: ["En Önemli Uyumsuzluk Alanları", "Organizasyonel Hizalanma Haritası", "Kanıt Paneli"],
        owner: "Liderlik algısıyla operasyonel gerçeklik arasındaki farkı gösterir."
      },
      {
        id: "kpi_gap_detection",
        title: "KPI Boşluk Tespiti",
        summary: "Ölçülmesi gereken ama ölçülmeyen göstergeleri bulur.",
        what: "Platform işletmenin ölçmesi gereken ama bugün ölçmediği önemli KPI’ları tespit eder.",
        why: "Ölçmediğiniz şeyi iyileştiremezsiniz.",
        inputs: ["Şirket DNA’sı", "İş faaliyetleri", "Operasyonel özellikler", "Mevcut KPI yanıtları"],
        outputs: ["Eksik KPI bulguları", "Gerekli veri noktaları", "Önerilen veri toplama yöntemi", "KPI kapsama skoru"],
        example: "Yol yardım hizmeti veren bir şirket acil yanıt süresini ölçmelidir. Ölçmüyorsa sistem eksik KPI bulgusu oluşturur.",
        widgets: ["Eksik KPI Radarı", "Şirket DNA Paneli", "Yönetici Özeti"],
        owner: "İşletmenin bugün hangi alanlarda kör olduğunu gösterir."
      },
      {
        id: "recommendation_engine",
        title: "Öneri Motoru",
        summary: "Onaylı bulgular uygulanabilir önerilere dönüşür.",
        what: "Platform onaylanmış bulguları uygulanabilir önerilere dönüştürür.",
        why: "Amaç problem toplamak değil, sıradaki doğru aksiyona karar vermektir.",
        inputs: ["Bulgular", "Kanıt", "Etki skorları", "Şirket bağlamı", "KPI boşlukları", "Problem tipleri"],
        outputs: ["Öneriler", "Beklenen faydalar", "Efor skoru", "İş değeri skoru", "Risk skoru"],
        example: "Bulgu: Yüksek manuel iş yükü. Öneri: Talep girişi, raporlama veya onay akışlarını otomatikleştir.",
        widgets: ["Fırsat Panosu", "Sonraki En İyi Aksiyon", "Öneri İncelemesi"],
        owner: "Teşhisi aksiyona dönüştürür."
      },
      {
        id: "roadmap_generator",
        title: "Yol Haritası Üretici",
        summary: "Öneriler fazlara ayrılmış iyileştirme planına dönüşür.",
        what: "Platform önerileri fazlara ayrılmış bir iyileştirme yol haritasına yerleştirir.",
        why: "Şirket sahiplerinin fikir listesine değil, sıralamaya ihtiyacı vardır.",
        inputs: ["Onaylı öneriler", "Öncelik skorları", "Efor skorları", "Bağımlılıklar", "İş değeri"],
        outputs: ["Hızlı Kazanımlar", "Temel Altyapı", "Optimizasyon", "Dönüşüm"],
        example: "Hızlı kazanım: dijital formlar. Temel: merkezi iş akışı. Optimizasyon: analitik. Dönüşüm: prediktif zeka.",
        widgets: ["Yol Haritası Görünümü", "Sonraki En İyi Aksiyon"],
        owner: "Önce ne yapılacağını, sonra ne kurulacağını ve ileride neyin mümkün olacağını gösterir."
      },
      {
        id: "owner_dashboard",
        title: "Sahip Dashboard’u",
        summary: "Karara hazır zekanın yönetici komuta merkezi.",
        what: "Şirket sahiplerinin en önemli içgörüleri gördüğü yönetici komuta merkezidir.",
        why: "Sahiplerin her yanıtı okuması veya her grafiği analiz etmesi gerekmez.",
        inputs: ["Onaylı bulgular", "Onaylı öneriler", "KPI boşlukları", "Mutabakat skorları", "Çelişkiler", "Yol haritası öğeleri"],
        outputs: ["İş Sağlığı Skoru", "En Önemli Problemler", "Eksik KPI Radarı", "Paydaş Mutabakatı", "Uyumsuzluk", "Fırsat Panosu", "Yol Haritası", "Sonraki En İyi Aksiyon"],
        example: "Sahip hemen şunu görür: “Eksik KPI görünürlüğü ve dispatch gecikmeleri çoklu paydaş grupları tarafından desteklenen yüksek öncelikli sorunlardır.”",
        widgets: ["Yönetici Özeti", "Sahip Dashboard’u", "Sonraki En İyi Aksiyon"],
        owner: "Dakikalar içinde karar vermeye hazır zeka sunar."
      }
    ]
  }
};

function getExplorerCopy() {
  return intelligenceExplorerCopy[publicExplorerLanguage] || intelligenceExplorerCopy.en;
}

function getActiveExplorerModule(copy = getExplorerCopy()) {
  return copy.modules.find((module) => module.id === activeExplorerModule) || copy.modules[0];
}

function getSavedSession() {
  try {
    return JSON.parse(localStorage.getItem("krbSession") || "null");
  } catch {
    return null;
  }
}

function saveSession(email, sessionToken = currentSessionToken) {
  const expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 14;
  currentSessionToken = sessionToken || currentSessionToken; // kept in memory only
  localStorage.setItem("krbCurrentUserEmail", email);
  // platformSessionToken deliberately NOT saved to localStorage — token stays in memory, HttpOnly cookie handles persistence
  localStorage.setItem("krbSession", JSON.stringify({ email, role: currentRole, user: currentUser, expiresAt }));
}

function clearSession() {
  localStorage.removeItem("krbCurrentUserEmail");
  localStorage.removeItem("krbSession");
  localStorage.removeItem("currentPlatformUser");
  localStorage.removeItem("platformSessionToken");
  currentSessionToken = "";
}

function showAuthPanel() {
  document.querySelector("#auth-screen")?.classList.remove("hidden");
  // #app-loading has inline display:flex — classList.add("hidden") loses to inline style.
  // Force-hide with inline style so the login form is visible.
  const loadingEl = document.querySelector("#app-loading");
  if (loadingEl) loadingEl.style.display = "none";
  document.querySelector("#login-section")?.classList.remove("hidden");
}

function handleAuthExpired(message = "Session expired. Please sign in again.") {
  clearSession();
  currentUser = null;
  currentUserEmail = "";
  currentRole = "participant";
  showAuthPanel();
  document.querySelector("#auth-form").classList.remove("hidden");
  document.querySelector("#forgot-password-form").classList.add("hidden");
  document.querySelector("#reset-password-form").classList.add("hidden");
  document.querySelector("#forgot-password-button").classList.remove("hidden");
  document.querySelector("#auth-title").textContent = "Sign in required";
  showPublicHomepageForSavedSession(); // hides "Open Dashboard" button now session is gone
  document.querySelector("#auth-subtitle").textContent = message; // must come after — overwrites the generic subtitle set by showPublicHomepageForSavedSession
}

function restoreSession() {
  const session = getSavedSession();
  const email = normalizeEmail(session?.email || currentUserEmail || "");
  if (!email || activeSurveyToken || activeResetToken) {
    return false;
  }
  if (session?.expiresAt && session.expiresAt < Date.now()) {
    clearSession();
    currentUserEmail = "";
    return false;
  }
  currentUserEmail = email;
  currentUser = session?.user || currentUser || platformUsers[email] || null;
  currentRole = session?.role || currentUser?.role || resolveRoleForEmail(email);
  localStorage.setItem("currentPlatformUser", JSON.stringify(currentUser));
  applyRole(currentRole);
  return true;
}

function showPublicHomepageForSavedSession() {
  const openButton = document.querySelector("#open-dashboard-button");
  if (!openButton) return;
  // currentSessionToken is memory-only — empty on page reload until login.
  // currentUserEmail is persisted via localStorage and cleared on logout, so it's
  // the correct signal for "user was logged in and hasn't explicitly signed out".
  const hasSession = Boolean(currentUserEmail);
  openButton.classList.toggle("hidden", !hasSession);
  document.querySelector("#auth-subtitle").textContent = hasSession
    ? "You are signed in. Open your workspace or sign in with a different account."
    : "Access the assessment command center.";
}

function openAuthenticatedApp() {
  if (!currentSessionToken) return;
  shouldOpenAppShell = true;
  const nextUrl = `${location.pathname}?app=1`;
  history.replaceState({}, "", nextUrl);
  document.querySelector("#auth-screen").classList.add("hidden");
  applyRole(currentRole);
  loadDatabaseState();
}

const titles = {
  "platform-command": "Platform Command Center",
  projects: "Organizations",
  dashboard: "Assessment Command Center",
  context: "Organization Profile",
  surveys: "Collection",
  "question-bank": "Framework Engine",
  meetings: "Discovery Meetings",
  stakeholders: "Stakeholder Coverage",
  findings: "Findings",
  opportunities: "Recommendations",
  roadmap: "Roadmap",
  "executive-preview": "Executive Dashboard",
  "executive-report": "Executive Report",
  "operations-center": "Operations Center",
  users: "Users & Access",
  methodology: "Framework Definition"
};

const screenStateCopy = {
  projects: {
    empty: {
      title: "No organizations yet",
      message: "Create an organization workspace to begin profile intake, blueprint, participant setup, analysis, and executive reporting.",
      actionLabel: "Create Organization",
      actionView: "projects"
    },
    permission: {
      title: "Organization portfolio is restricted",
      message: "Only platform owners and assigned consultants can open the organization portfolio."
    }
  },
  context: {
    empty: {
      title: "Open an organization first",
      message: "Organization Profile is saved inside an organization workspace. Select an organization before completing the intake.",
      actionLabel: "Open Organizations",
      actionView: "projects"
    }
  },
  "assessment-blueprint": {
    empty: {
      title: "Blueprint is not generated yet",
      message: "Organization Profile is required before the platform can recommend stakeholder roles, question banks, KPI sets, and coverage gaps.",
      actionLabel: "Generate Blueprint",
      actionId: "generate-assessment-blueprint"
    }
  },
  participants: {
    empty: {
      title: "No participants added yet",
      message: "Add participants manually or upload a stakeholder list to launch the assessment.",
      actionLabel: "Add Participant",
      actionId: "assessment-participant-form"
    },
    warning: {
      title: "Participant coverage is incomplete",
      message: "Required roles need assigned participants and completed sessions before owner insights are reliable."
    }
  },
  "participant-upload": {
    empty: {
      title: "No upload preview yet",
      message: "Download the template, upload a stakeholder list, then preview validation results before importing.",
      actionLabel: "Download Template",
      actionId: "download-participant-template"
    }
  },
  respondent: {
    loading: {
      title: "Loading assessment",
      message: "Please wait while we verify your secure assessment link."
    },
    empty: {
      title: "No questions are available",
      message: "This role does not have an active question bank yet. Please contact the assessment administrator."
    },
    success: {
      title: "Assessment Completed",
      message: "Thank you. Your responses have been submitted."
    },
    error: {
      title: "Assessment link unavailable",
      message: "This link is invalid, expired, or has been regenerated. Please request a fresh link from the assessment administrator."
    }
  },
  analysis: {
    empty: {
      title: "Assessment engine is waiting",
      message: "Create an assessment, collect completed stakeholder sessions, then run analysis to generate findings, evidence, recommendations, and roadmap items.",
      actionLabel: "Create Assessment",
      actionId: "create-assessment-engine"
    },
    warning: {
      title: "Analysis is incomplete",
      message: "Completed sessions exist, but findings, evidence, recommendations, or roadmap items are not fully generated yet."
    }
  },
  findings: {
    empty: {
      title: "No findings yet",
      message: "Run the assessment engine after stakeholder sessions are completed. Findings will appear here for approval, rejection, editing, archiving, and merging.",
      actionLabel: "Run Analysis",
      actionId: "run-assessment-analysis"
    }
  },
  evidence: {
    empty: {
      title: "Select a finding",
      message: "Evidence Explorer links each finding back to source questions, responses, stakeholder roles, groups, and trigger rules."
    }
  },
  recommendations: {
    empty: {
      title: "No recommendations yet",
      message: "Recommendations will appear after findings are generated and reviewed.",
      actionLabel: "Open Findings",
      actionView: "findings"
    },
    warning: {
      title: "Recommendations need approval",
      message: "Draft recommendations do not appear in owner-facing outputs until approved."
    }
  },
  roadmap: {
    empty: {
      title: "No roadmap items yet",
      message: "Roadmap items will appear after approved recommendations are generated and sequenced.",
      actionLabel: "Open Recommendations",
      actionView: "opportunities"
    }
  },
  "owner-dashboard": {
    empty: {
      title: "Assessment is still in progress",
      message: "Owner insights will appear after approved findings and recommendations are available.",
      actionLabel: "Open Findings Workbench",
      actionView: "findings"
    }
  },
  "executive-report": {
    empty: {
      title: "Executive report is not ready yet",
      message: "Approve findings and recommendations first, then generate the formal executive-ready report.",
      actionLabel: "Open Findings Workbench",
      actionView: "findings"
    }
  },
  "progress-history": {
    empty: {
      title: "No progress baseline yet",
      message: "Generate a progress snapshot after an assessment to establish organizational memory.",
      actionLabel: "Generate Progress Snapshot",
      actionId: "generate-progress-snapshot"
    }
  },
  "operations-center": {
    loading: {
      title: "Refreshing mission control",
      message: "Loading workflow health, participants, communications, links, analysis, reports, issues, logs, QA, and system status."
    },
    empty: {
      title: "No operations records yet",
      message: "Operations Center will populate after organization assessments, participants, links, analysis, or QA records exist.",
      actionLabel: "Open Assessment Builder",
      actionView: "dashboard"
    },
    error: {
      title: "Operations Center could not load",
      message: "The system could not load mission control data. Try refresh, then check system health if the issue continues."
    }
  },
  "audit-logs": {
    empty: {
      title: "No audit events recorded yet",
      message: "Audit logs will appear as users create participants, sessions, links, invitations, responses, analysis, reports, snapshots, or issues."
    }
  },
  "qa-history": {
    empty: {
      title: "No QA runs recorded yet",
      message: "QA history will show pass/fail runs, failed checks, record counts, and cleanup status."
    }
  },
  "system-health": {
    empty: {
      title: "System health has no recent events",
      message: "No recent backend errors or workflow warnings are recorded."
    }
  }
};

const viewRoleAccess = {
  "platform-command": ["platform_owner"],
  projects: ["platform_owner", "consultant"],
  dashboard: ["platform_owner", "consultant", "assessment_manager"],
  context: ["platform_owner", "consultant", "company_owner"],
  findings: ["platform_owner", "consultant"],
  opportunities: ["platform_owner", "consultant"],
  roadmap: ["platform_owner", "consultant", "company_owner"],
  "executive-preview": ["platform_owner", "consultant", "company_owner"],
  "executive-report": ["platform_owner", "consultant", "company_owner"],
  "operations-center": ["platform_owner"],
  users: ["platform_owner"],
  "question-bank": ["platform_owner"],
  methodology: ["platform_owner"],
  surveys: ["legacy_hidden"],
  stakeholders: ["legacy_hidden"],
  meetings: ["legacy_hidden"]
};

function renderStateAction(config = {}) {
  if (!config.actionLabel) return "";
  const label = escapeHtml(config.actionLabel);
  if (config.actionView) return `<button class="primary-button state-action" data-state-view="${escapeHtml(config.actionView)}" type="button">${label}</button>`;
  if (config.actionId) return `<button class="primary-button state-action" data-state-target="${escapeHtml(config.actionId)}" type="button">${label}</button>`;
  return "";
}
// DUPLICATED → shared.js — remove from app.js after
// all role modules verified working

function renderScreenState(screenId, state = "empty", overrides = {}) {
  const config = {
    ...(screenStateCopy[screenId]?.[state] || {}),
    ...overrides
  };
  const status = state === "error" ? "error" : state === "warning" ? "warning" : state === "success" ? "success" : state === "loading" ? "loading" : state === "permission" ? "permission" : "empty";
  return `
    <article class="screen-state screen-state-${status} ${overrides.compact ? "compact" : ""}" role="${status === "error" || status === "warning" ? "alert" : "status"}">
      <span class="state-badge">${escapeHtml(status === "permission" ? "Permission Denied" : status)}</span>
      <strong>${escapeHtml(config.title || "No data available")}</strong>
      <p>${escapeHtml(config.message || "This screen will populate when the required data is available.")}</p>
      ${config.details ? `<small>${escapeHtml(config.details)}</small>` : ""}
      ${renderStateAction(config)}
    </article>
  `;
}
// DUPLICATED → shared.js — remove from app.js after
// all role modules verified working

function renderLoadingSkeleton(title = "Loading", rows = 4) {
  return `
    <article class="screen-state screen-state-loading" role="status">
      <span class="state-badge">loading</span>
      <strong>${escapeHtml(title)}</strong>
      <div class="state-skeleton-list">
        ${Array.from({ length: rows }).map(() => `<i></i>`).join("")}
      </div>
    </article>
  `;
}
// DUPLICATED → shared.js — remove from app.js after
// all role modules verified working

function viewAllowedForRole(viewId, role = currentRole) {
  if (activeSurveyToken && viewId === "surveys") return true;
  const normalizedRole = normalizeAppRole(role);
  if (viewRoleAccess[viewId]) return viewRoleAccess[viewId].includes(normalizedRole);
  const buttons = [...document.querySelectorAll(`[data-view="${viewId}"]`)];
  const button = buttons.find((item) => {
    if (item.classList.contains("hidden")) return false;
    const roles = item.dataset.roles ? item.dataset.roles.split(" ") : [];
    return !roles.length || roles.includes(normalizedRole);
  }) || buttons[0];
  if (!button?.dataset.roles) return true;
  return button.dataset.roles.split(" ").includes(normalizedRole);
}

function ensurePermissionDeniedView() {
  let view = document.querySelector("#permission-denied");
  if (view) return view;
  view = document.createElement("section");
  view.className = "view";
  view.id = "permission-denied";
  document.querySelector(".main")?.appendChild(view);
  return view;
}

function saveResponses() {
  localStorage.setItem("krbResponses", JSON.stringify(responses));
}

function saveSurveyInvites() {
  localStorage.setItem("krbSurveyInvites", JSON.stringify(surveyInvites));
}

function saveProjectParticipants() {
  localStorage.setItem("projectParticipants", JSON.stringify(projectParticipants));
}

function saveProjectContextIntake() {
  localStorage.setItem("projectContextIntake", JSON.stringify(projectContextIntake));
}

function saveCompanyProfile() {
  localStorage.setItem("companyProfile", JSON.stringify(companyProfile));
}

function saveActiveContextLanguage(language) {
  activeContextLanguage = language === "en" ? "en" : "tr";
  localStorage.setItem("activeContextLanguage", activeContextLanguage);
}

function slugifyStakeholderRole(role) {
  return String(role)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function getStakeholderRoleOptions() {
  return stakeholderArchitecture.flatMap((scope) =>
    scope.groups.flatMap((group) =>
      group.roles.map((role) => {
        const id = slugifyStakeholderRole(role);
        return {
          id,
          role,
          scope: scope.scope,
          family: group.family,
          templateCode: stakeholderRoleAliases[id] || id
        };
      })
    )
  );
}

function getSelectedStakeholderRoleIds() {
  const selected = projectContextIntake?.contextData?.selectedStakeholderRoles || [];
  return new Set(selected.map((item) => (typeof item === "string" ? item : item.id)).filter(Boolean));
}

function getSelectedBusinessDomainIds() {
  const selected = projectContextIntake?.contextData?.selectedBusinessDomains || [];
  return new Set(selected.map((item) => (typeof item === "string" ? item : item.id)).filter(Boolean));
}

function getSelectedAssessmentCategoryIds() {
  const selected = projectContextIntake?.contextData?.selectedAssessmentCategories || [];
  return new Set(selected.map((item) => (typeof item === "string" ? item : item.id)).filter(Boolean));
}

function getProblemTypeOptions() {
  return problemTypesTaxonomy.flatMap((group) => group.items.map((item) => ({ ...item, group: group.group })));
}

function getSelectedProblemTypeIds() {
  const selected = projectContextIntake?.contextData?.selectedProblemTypes || [];
  return new Set(selected.map((item) => (typeof item === "string" ? item : item.id)).filter(Boolean));
}

function calculatePriorityScore(finding) {
  const weighted = Object.entries(scoringModel.priorityWeights).reduce((sum, [field, weight]) => {
    return sum + Number(finding[field] || 0) * weight;
  }, 0);
  return Math.round(Math.max(0, Math.min(100, weighted * 20)));
}

function classifyPriority(score) {
  return scoringModel.classificationBands.find((band) => score >= band.min && score <= band.max)?.label || "Minor";
}

function persistSelectedStakeholderRoles(selectedIds) {
  const selected = getStakeholderRoleOptions().filter((role) => selectedIds.has(role.id));
  projectContextIntake = {
    ...(projectContextIntake || {}),
    language: getContextLanguage(),
    contextData: {
      ...(projectContextIntake?.contextData || {}),
      selectedStakeholderRoles: selected
    }
  };
  saveProjectContextIntake();
}

function persistSelectedBusinessDomains(selectedIds) {
  const selected = businessDomainsTaxonomy.filter((domain) => selectedIds.has(domain.id));
  projectContextIntake = {
    ...(projectContextIntake || {}),
    language: getContextLanguage(),
    contextData: {
      ...(projectContextIntake?.contextData || {}),
      selectedBusinessDomains: selected
    }
  };
  saveProjectContextIntake();
}

function persistSelectedAssessmentCategories(selectedIds) {
  const selected = assessmentCategoriesTaxonomy.filter((category) => selectedIds.has(category.id));
  projectContextIntake = {
    ...(projectContextIntake || {}),
    language: getContextLanguage(),
    contextData: {
      ...(projectContextIntake?.contextData || {}),
      selectedAssessmentCategories: selected
    }
  };
  saveProjectContextIntake();
}

function persistSelectedProblemTypes(selectedIds) {
  const selected = getProblemTypeOptions().filter((problemType) => selectedIds.has(problemType.id));
  projectContextIntake = {
    ...(projectContextIntake || {}),
    language: getContextLanguage(),
    contextData: {
      ...(projectContextIntake?.contextData || {}),
      selectedProblemTypes: selected
    }
  };
  saveProjectContextIntake();
}

function syncSelectedStakeholderRoles() {
  if (!currentSessionToken || activeContextToken || !activeProject?.id) return;
  clearTimeout(stakeholderRoleSaveTimer);
  stakeholderRoleSaveTimer = setTimeout(async () => {
    try {
      const payload = await apiRequest("/api/project-context", {
        method: "POST",
        body: JSON.stringify({
          projectId: activeProject.id,
          token: projectContextIntake?.token,
          recipientName: projectContextIntake?.recipientName || "",
          recipientEmail: projectContextIntake?.recipientEmail || "",
          language: projectContextIntake?.language || getContextLanguage(),
          contextData: projectContextIntake?.contextData || {}
        })
      });
      projectContextIntake = payload.intake;
      saveProjectContextIntake();
    } catch (error) {
      console.warn("Stakeholder role selection sync failed.", error);
    }
  }, 400);
}

function syncProjectContextSelection() {
  syncSelectedStakeholderRoles();
}

function saveProjects() {
  localStorage.setItem("assessmentProjects", JSON.stringify(assessmentProjects));
}

function saveActiveProject(project) {
  activeProject = project;
  localStorage.setItem("activeAssessmentProject", JSON.stringify(project));
  renderProjectAccessOptions();
}

function clearActiveWorkspace() {
  activeProject = null;
  activeProjectWorkspaceOpen = false;
  localStorage.removeItem("activeAssessmentProject");
  localStorage.removeItem("activeProjectWorkspaceOpen");
  surveyInvites = [];
  responses = [];
  projectParticipants = [];
  projectContextIntake = null;
  companyProfile = null;
  assessmentEngineState = null;
  executiveReportState = null;
  saveSurveyInvites();
  saveResponses();
  saveProjectParticipants();
  saveProjectContextIntake();
  saveCompanyProfile();
}

function openProjectWorkspace(project) {
  saveActiveProject(project);
  activeProjectWorkspaceOpen = true;
  executiveReportState = null;
  localStorage.setItem("activeProjectWorkspaceOpen", "true");
}

function isPortfolioRole(role = currentRole) {
  return ["platform_owner", "consultant"].includes(normalizeAppRole(role));
}

function hasActiveWorkspace() {
  return Boolean(activeProject?.id && (activeProjectWorkspaceOpen || !isPortfolioRole()));
}

function platformProjectIdFallback() {
  const platformState = window.__platformState || {};
  return activeProject?.id
    || getSlice("platform")?.activeProjectId
    || platformState.selectedAssessmentOrgId
    || null;
}

function activeProjectQuery() {
  return hasActiveWorkspace() ? `?projectId=${encodeURIComponent(activeProject.id)}` : "";
}

function saveOutlookConfig() {
  localStorage.setItem("krbOutlookConfig", JSON.stringify(outlookConfig));
}

function savePlatformUsers() {
  localStorage.setItem("krbPlatformUsers", JSON.stringify(platformUsers));
}

function saveParticipantAccessLinks() {
  localStorage.setItem("participantAccessLinks", JSON.stringify(participantAccessLinks));
}

async function apiRequest(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    // No Authorization header — HttpOnly cookie is the auth mechanism
    ...(options.headers || {})
  };
  const response = await fetch(path, {
    headers,
    credentials: "same-origin",
    ...options
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = payload.message || payload.error || `Request failed with ${response.status}`;
    const error = new Error(message);
    Object.assign(error, payload);
    if (response.status === 401 && !path.startsWith("/api/auth/") && !path.startsWith("/api/project-context/public") && !path.startsWith("/api/respond/")) {
      error.message = "Session expired. Please sign in again before sending or saving.";
      error.authExpired = true;
      handleAuthExpired(error.message);
    }
    throw error;
  }
  return payload;
}

function seedStoreFromGlobals() {
  // ── STORE SEED ──────────────────────────────────────
  // Mirrors live globals into store.
  // Globals remain active source of truth until
  // all components migrated and verified.
  // Do not remove globals until each role surface
  // is fully extracted and verified in production.

  mergeState('session', {
    currentRole:              currentRole ?? null,
    currentUser:              currentUser ?? null,
    currentUserEmail:         currentUserEmail ?? null,
    currentSessionToken:      currentSessionToken ?? null,
    activeViewId:             activeViewId ?? null,
    activeQuestionBankRole:   activeQuestionBankRole ?? null,
    shouldOpenAppShell:       shouldOpenAppShell ?? false
  });

  mergeState('platform', {
    projects:               assessmentProjects ?? [],
    activeProjectId:        activeProject?.id ?? null,
    users:                  platformUsers ?? {},
    metrics:                platformCommandCenterState ?? null,
    commandCenterError:     platformCommandCenterError ?? null,
    classificationFilter:   platformClassificationFilter ?? null
  });

mergeState('assessment', {
  assessment:                 assessmentEngineState?.assessment ?? null,
  activeAssessmentId:         assessmentEngineState?.assessment?.id ?? null,
  blueprint:                  assessmentEngineState?.blueprint ?? assessmentEngineState?.assessmentBlueprint ?? null,
    participants:               assessmentEngineState?.assessmentParticipants ?? [],
    sessions:                   assessmentEngineState?.sessions ?? [],
    findings:                   assessmentEngineState?.findings ?? [],
    evidence:                   assessmentEngineState?.evidence ?? [],
    clusters:                   assessmentEngineState?.clusters ?? [],
    recommendations:            assessmentEngineState?.recommendations ?? [],
    roadmapItems:               assessmentEngineState?.roadmapItems ?? [],
    coverage:                   assessmentEngineState?.participantCoverage ?? null,
    progressMemory:             assessmentEngineState?.progressMemory ?? null,
    managerCommandCenterState:  assessmentManagerCommandCenterState ?? null,
    managerCommandCenterError:  assessmentManagerCommandCenterError ?? null
  });

  mergeState('executive', {
    report: executiveReportState ?? null,
    ownerFilterState: {
      stakeholderGroup:       ownerStakeholderGroupFilter ?? null,
      stakeholderRole:        ownerStakeholderRoleFilter ?? null,
      heatmapDomain:          ownerHeatmapDomainFilter ?? null,
      heatmapGroup:           ownerHeatmapGroupFilter ?? null,
      heatmapMinPriority:     ownerHeatmapMinPriority ?? null,
      onlyMisalignment:       ownerHeatmapOnlyMisalignment ?? false,
      onlyHighConfidence:     ownerHeatmapOnlyHighConfidence ?? false,
      selectedHeatmapCellKey: selectedHeatmapCellKey ?? null
    }
  });

  mergeState('consultant', {
    commandCenterState: consultantCommandCenterState ?? null,
    commandCenterError: consultantCommandCenterError ?? null
  });

  mergeState('operations', {
    krbOperationsState: krbOperationsState ?? {},
    section:            krbOperationsSection ?? null,
    loading:            krbOperationsLoading ?? false,
    error:              krbOperationsError ?? null,
    lastRefreshed:      krbOperationsLastRefreshed ?? null
  });
  mergeState('framework', {
    roles: questionBankRoles ?? []
  });
  // ── END STORE SEED ───────────────────────────────────
}

function refreshOwnerSurfaceFromStore() {
  if (normalizeAppRole(currentRole) !== "company_owner") return;
  import("./shells/owner.js").then(({ renderOwnerView }) => {
    const ownerState = window.__ownerState;
    if (ownerState) {
      renderOwnerView(ownerState.activeView);
    }
  }).catch((err) => {
    console.error("Owner shell failed to refresh:", err);
  });
}

function refreshConsultantSurfaceFromStore() {
  if (normalizeAppRole(currentRole) !== "consultant") return;
  import("./shells/consultant.js").then(({ renderConsultantView }) => {
    const consultantState = window.__consultantState;
    if (consultantState) {
      renderConsultantView(consultantState.activeView);
    }
  }).catch((err) => {
    console.error("Consultant shell failed to refresh:", err);
  });
}

function refreshManagerSurfaceFromStore() {
  if (normalizeAppRole(currentRole) !== "assessment_manager") return;
  import("./shells/manager.js").then(({ renderManagerShell, renderManagerStep }) => {
    const managerState = window.__managerState;
    const container = document.getElementById("manager-surface");
    if (managerState) {
      if (container) renderManagerShell(container);
      renderManagerStep(managerState.activeStep);
    }
  }).catch((err) => {
    console.error("Manager shell failed to refresh:", err);
  });
}

function refreshPlatformSurfaceFromStore() {
  if (normalizeAppRole(currentRole) !== "platform_owner") return;
  import("./shells/platform.js").then(({ renderPlatformView }) => {
    const platformState = window.__platformState;
    if (platformState) {
      renderPlatformView(platformState.activeView);
    }
  }).catch((err) => {
    console.error("Platform shell failed to refresh:", err);
  });
}

async function renderActiveReviewSurfaces() {
  await Promise.all([
    import("./shells/platform.js").then(({ renderPlatformView }) => {
      const platformState = window.__platformState;
      if (platformState?.activeView) {
        renderPlatformView(platformState.activeView);
      }
    }).catch((err) => {
      console.error("Platform shell failed to render:", err);
    }),
    import("./shells/consultant.js").then(({ renderConsultantView }) => {
      const consultantState = window.__consultantState;
      if (consultantState?.activeView) {
        renderConsultantView(consultantState.activeView);
      }
    }).catch((err) => {
      console.error("Consultant shell failed to render:", err);
    })
  ]);
}

function normalizeReviewStatus(status) {
  const normalized = String(status || "").toLowerCase().trim();
  const map = {
    approved: "Approved",
    rejected: "Rejected",
    draft: "Draft",
    proposed: "Proposed",
    accepted: "Accepted",
    in_progress: "In Progress",
    "in progress": "In Progress",
    completed: "Completed"
  };
  return map[normalized] || status;
}

async function loadDatabaseState() {
  try {
    const projectPayload = await apiRequest("/api/projects");
    if (Array.isArray(projectPayload.projects)) {
      assessmentProjects = projectPayload.projects;
      if (!hasActiveWorkspace() && activeProject?.id && !assessmentProjects.some((project) => project.id === activeProject.id)) {
        clearActiveWorkspace();
      }
      if (!activeProject && normalizeAppRole(currentRole) === "assessment_manager" && currentUser?.projectId) {
        const assignedProject = assessmentProjects.find((project) => String(project.id) === String(currentUser.projectId)) || {
          id: currentUser.projectId,
          organizationId: currentUser.organizationId || null,
          clientDisplayName: currentUser.organizationName || currentUser.companyName || "Assigned Organization",
          name: currentUser.projectName || "Assigned Assessment",
          status: "active"
        };
        if (!assessmentProjects.some((project) => String(project.id) === String(assignedProject.id))) {
          assessmentProjects = [assignedProject, ...assessmentProjects];
        }
        saveActiveProject(assignedProject);
        mergeState("platform", {
          projects: assessmentProjects,
          activeProjectId: assignedProject.id
        });
      }
      if (!activeProject && assessmentProjects.length && !isPortfolioRole()) {
        saveActiveProject(assessmentProjects[0]);
      }
      if (!activeProject && assessmentProjects.length && normalizeAppRole(currentRole) === "consultant") {
        saveActiveProject(assessmentProjects[0]);
      }
      saveProjects();
    }
    if (normalizeAppRole(currentRole) === "consultant") {
      try {
        consultantCommandCenterState = await apiRequest("/api/consultant-command-center");
        consultantCommandCenterError = "";
      } catch (error) {
        consultantCommandCenterState = null;
        consultantCommandCenterError = error.message;
      }
    } else {
      consultantCommandCenterState = null;
      consultantCommandCenterError = "";
    }
    if (normalizeAppRole(currentRole) === "platform_owner") {
      try {
        platformCommandCenterState = await apiRequest("/api/platform-command-center");
        platformCommandCenterError = "";
      } catch (error) {
        platformCommandCenterState = null;
        platformCommandCenterError = error.message;
      }
    } else {
      platformCommandCenterState = null;
      platformCommandCenterError = "";
    }
    if (normalizeAppRole(currentRole) === "assessment_manager") {
      try {
        assessmentManagerCommandCenterState = await apiRequest("/api/assessment-manager-command-center");
        assessmentManagerCommandCenterError = "";
      } catch (error) {
        assessmentManagerCommandCenterState = null;
        assessmentManagerCommandCenterError = error.message;
      }
    } else {
      assessmentManagerCommandCenterState = null;
      assessmentManagerCommandCenterError = "";
    }
    if (!hasActiveWorkspace()) {
      surveyInvites = [];
      responses = [];
      projectParticipants = [];
      projectContextIntake = null;
      companyProfile = null;
      assessmentEngineState = null;
      executiveReportState = null;
      saveSurveyInvites();
      saveResponses();
      saveProjectParticipants();
      saveProjectContextIntake();
      saveCompanyProfile();
      await loadUsersFromDatabase();
      seedStoreFromGlobals();
      seedStoreFromGlobals();
      const role = normalizeAppRole(currentRole);
      if (role === 'company_owner') {
        import('./shells/owner.js')
          .then(({ renderOwnerView }) => {
            const os = window.__ownerState;
            if (os) renderOwnerView(os.activeView);
          });
      } else if (role === 'consultant') {
        import('./shells/consultant.js')
          .then(({ renderConsultantView }) => {
            const cs = window.__consultantState;
            if (cs) renderConsultantView(cs.activeView);
          });
      } else if (role === 'assessment_manager') {
        import('./shells/manager.js')
          .then(({ renderManagerStep }) => {
            const ms = window.__managerState;
            if (ms) renderManagerStep(ms.activeStep);
          });
      } else if (role === 'platform_owner') {
        import('./shells/platform.js')
          .then(({ renderPlatformView }) => {
            const ps = window.__platformState;
            if (ps) renderPlatformView(ps.activeView);
          });
      }
      refreshOwnerSurfaceFromStore();
      refreshConsultantSurfaceFromStore();
      refreshManagerSurfaceFromStore();
      refreshPlatformSurfaceFromStore();
      return;
    }
    const [assignmentPayload, responsePayload, participantPayload, contextPayload, enginePayload] = await Promise.all([
      apiRequest(`/api/survey-assignments${activeProjectQuery()}`).catch((error) => ({ assignments: [], error: error.message })),
      apiRequest(`/api/responses${activeProjectQuery()}`).catch((error) => ({ responses: [], error: error.message })),
      apiRequest(`/api/project-participants${activeProjectQuery()}`).catch((error) => ({ participants: [], error: error.message })),
      apiRequest(`/api/project-context${activeProjectQuery()}`).catch((error) => ({ intake: projectContextIntake, companyProfile, error: error.message })),
      apiRequest(`/api/assessment-engine${activeProjectQuery()}`).catch((error) => ({ error: error.message }))
    ]);
    if (Array.isArray(assignmentPayload.assignments)) {
      surveyInvites = assignmentPayload.assignments;
      saveSurveyInvites();
    }
    if (Array.isArray(responsePayload.responses)) {
      responses = responsePayload.responses;
      saveResponses();
    }
    if (Array.isArray(participantPayload.participants)) {
      projectParticipants = participantPayload.participants;
      saveProjectParticipants();
    }
    if (Object.prototype.hasOwnProperty.call(contextPayload, "intake")) {
      projectContextIntake = contextPayload.intake;
      saveProjectContextIntake();
    }
    if (contextPayload.companyProfile) {
      companyProfile = contextPayload.companyProfile;
      saveCompanyProfile();
    }
    if (!enginePayload.error) {
      assessmentEngineState = enginePayload;
      if (enginePayload.companyProfile) {
        companyProfile = enginePayload.companyProfile;
        saveCompanyProfile();
      }
    }
    if (activeProject) {
      activeProject.assignmentCount = surveyInvites.length;
      activeProject.responseCount = responses.length;
      const index = assessmentProjects.findIndex((project) => project.id === activeProject.id);
      if (index >= 0) {
        assessmentProjects[index] = { ...assessmentProjects[index], ...activeProject };
        saveProjects();
      }
    }
    await loadUsersFromDatabase();
    seedStoreFromGlobals();
    seedStoreFromGlobals();
    const role = normalizeAppRole(currentRole);
    if (role === 'platform_owner') {
      import('./shells/platform.js')
        .then(({ renderPlatformView }) => {
          const ps = window.__platformState;
          if (ps) {
            renderPlatformView(ps.activeView);
          } else {
            renderPlatformView('command-center');
          }
        });
    } else if (role === 'company_owner') {
      import('./shells/owner.js')
        .then(({ renderOwnerView }) => {
          const os = window.__ownerState;
          if (os) renderOwnerView(os.activeView);
        });
    } else if (role === 'consultant') {
      import('./shells/consultant.js')
        .then(({ renderConsultantView }) => {
          const cs = window.__consultantState;
          if (cs) renderConsultantView(cs.activeView);
        });
    } else if (role === 'assessment_manager') {
      import('./shells/manager.js')
        .then(({ renderManagerStep }) => {
          const ms = window.__managerState;
          if (ms) renderManagerStep(ms.activeStep);
        });
    }
    refreshOwnerSurfaceFromStore();
    refreshConsultantSurfaceFromStore();
    refreshManagerSurfaceFromStore();
    refreshPlatformSurfaceFromStore();
  } catch (error) {
    console.warn("Database hydration failed; using local state.", error);
  }
}

async function loadPublicContextIntake() {
  if (!activeContextToken) return false;
  try {
    const payload = await apiRequest(`/api/project-context/public?token=${encodeURIComponent(activeContextToken)}`);
    projectContextIntake = payload.intake;
    activeProject = {
      id: payload.intake.projectId,
      clientDisplayName: payload.intake.clientDisplayName || payload.intake.organizationName || "Company",
      name: payload.intake.projectName || "Digital Transformation Assessment",
      defaultLanguage: payload.intake.language || "tr"
    };
    saveProjectContextIntake();
    document.querySelector("#auth-screen").classList.add("hidden");
    currentRole = "participant";
    applyRole("participant");
    setActiveView("context");
    renderProjectContextForm();
    renderContextSummary();
    document.querySelector("#context-form-output").innerHTML = `<span>${getContextLanguage() === "tr" ? "Lütfen şirket bilgilerini doldurun ve kaydedin." : "Please complete and save the company context form."}</span>`;
    return true;
  } catch (error) {
    document.querySelector("#auth-subtitle").textContent = error.message || "Context intake link failed.";
    return false;
  }
}

function storePlatformUser(user) {
  if (!user?.email) return;
  platformUsers[user.email] = {
    ...(platformUsers[user.email] || {}),
    id: user.id || platformUsers[user.email]?.id || user.email,
    name: user.name,
    email: user.email,
    role: normalizeAppRole(user.role),
    projectId: user.projectId || user.project_id || platformUsers[user.email]?.projectId || activeProject?.id || "",
    password: user.password || platformUsers[user.email]?.password || "",
    status: user.status || "active",
    createdAt: user.createdAt || platformUsers[user.email]?.createdAt || new Date().toISOString(),
    credentialsSentAt: user.credentialsSentAt || platformUsers[user.email]?.credentialsSentAt || null
  };
  savePlatformUsers();
}

async function loadUsersFromDatabase() {
  try {
    const qs = activeProject?.id && normalizeAppRole(currentRole) !== "platform_owner" ? `?projectId=${encodeURIComponent(activeProject.id)}` : "";
    const payload = await apiRequest(`/api/users${qs}`);
    if (Array.isArray(payload.users)) {
      platformUsers = {};
      payload.users.forEach(storePlatformUser);
      mergeState("platform", { users: platformUsers ?? {} });
      refreshPlatformSurfaceFromStore();
    }
  } catch (error) {
    console.warn("User hydration failed; using local user cache.", error);
  }
}

async function refreshPlatformUsers() {
  const payload = await apiRequest("/api/users");
  if (Array.isArray(payload.users)) {
    platformUsers = {};
    payload.users.forEach(storePlatformUser);
    mergeState("platform", { users: platformUsers ?? {} });
  }
  refreshPlatformSurfaceFromStore();
}

async function sendCredentials(userId) {
  const btn = Array.from(document.querySelectorAll("[data-component-send-credentials]"))
    .find((button) => String(button.getAttribute("data-component-send-credentials")) === String(userId));
  if (btn) {
    btn.disabled = true;
    btn.textContent = "Sending...";
  }
  try {
    await apiRequest(`/api/users/${encodeURIComponent(userId)}/send-credentials`, {
      method: "POST",
      body: JSON.stringify({})
    });
    if (btn) {
      btn.textContent = "Sent ✓";
      setTimeout(() => {
        btn.disabled = false;
        btn.textContent = "Creds";
      }, 3000);
    }
  } catch (error) {
    if (btn) {
      btn.disabled = false;
      btn.textContent = "Creds";
    }
    console.error("Send credentials failed:", error.message);
  }
}

function renderProjectAccessOptions() {
  const select = document.querySelector("#role-user-project");
  if (!select) return;
  const currentId = activeProject?.id || assessmentProjects[0]?.id || "";
  select.innerHTML = assessmentProjects
    .map((project) => `<option value="${project.id}" ${project.id === currentId ? "selected" : ""}>${project.clientDisplayName || project.organizationName || project.name}</option>`)
    .join("");
}

async function loadActiveSurveyAssignment() {
  if (!activeSurveyToken) return;
  try {
    const payload = await apiRequest(`/api/survey-assignments/${encodeURIComponent(activeSurveyToken)}`);
    if (payload.assignment) {
      const existingIndex = surveyInvites.findIndex((invite) => invite.token === payload.assignment.token);
      if (existingIndex >= 0) {
        surveyInvites[existingIndex] = payload.assignment;
      } else {
        surveyInvites.unshift(payload.assignment);
      }
      activeSurveyLanguage = payload.assignment.language || activeSurveyLanguage;
      saveSurveyInvites();
      renderSurveyForm(payload.assignment.templateId);
    }
  } catch (error) {
    console.warn("Active survey assignment lookup failed; using URL metadata.", error);
  }
}

async function persistSurveyAssignment(invite) {
  try {
    await apiRequest("/api/survey-assignments", {
      method: "POST",
      body: JSON.stringify({ ...invite, projectId: activeProject?.id })
    });
  } catch (error) {
    document.querySelector("#share-box").innerHTML += `<p><strong>Database sync warning:</strong> ${error.message}</p>`;
  }
}

async function persistSurveyResponse(response) {
  return apiRequest("/api/responses", {
    method: "POST",
    body: JSON.stringify({ ...response, projectId: activeProject?.id })
  });
}

async function refreshAssessmentEngine() {
  if (!activeProject?.id) return;
  try {
    assessmentEngineState = await apiRequest(`/api/assessment-engine${activeProjectQuery()}`);
    if (normalizeAppRole(currentRole) === "assessment_manager") {
      try {
        assessmentManagerCommandCenterState = await apiRequest("/api/assessment-manager-command-center");
        assessmentManagerCommandCenterError = "";
      } catch (error) {
        assessmentManagerCommandCenterError = error.message;
      }
    }
    mergeState('assessment', {
      assessment:                assessmentEngineState?.assessment ?? null,
      activeAssessmentId:        assessmentEngineState?.assessment?.id ?? null,
      blueprint:                 assessmentEngineState?.blueprint ?? assessmentEngineState?.assessmentBlueprint ?? null,
      participants:              assessmentEngineState?.assessmentParticipants ?? [],
      sessions:                  assessmentEngineState?.sessions ?? [],
      findings:                  assessmentEngineState?.findings ?? [],
      evidence:                  assessmentEngineState?.evidence ?? [],
      clusters:                  assessmentEngineState?.clusters ?? [],
      recommendations:           assessmentEngineState?.recommendations ?? [],
      roadmapItems:              assessmentEngineState?.roadmapItems ?? [],
      coverage:                  assessmentEngineState?.participantCoverage ?? null,
      progressMemory:            assessmentEngineState?.progressMemory ?? null,
      managerCommandCenterState: assessmentManagerCommandCenterState ?? null,
      managerCommandCenterError: assessmentManagerCommandCenterError ?? null
    });
    refreshOwnerSurfaceFromStore();
    refreshConsultantSurfaceFromStore();
    refreshManagerSurfaceFromStore();
    refreshPlatformSurfaceFromStore();
  } catch (error) {
    assessmentEngineState = null;
    console.warn("Assessment engine refresh failed.", error);
  }
}

async function refreshExecutiveReport() {
  const container = document.querySelector("#executive-report-content");
  const projectId = platformProjectIdFallback();
  if (!projectId) {
    executiveReportState = null;
    setState('executive', 'report', executiveReportState ?? null);
    refreshOwnerSurfaceFromStore();
    refreshConsultantSurfaceFromStore();
    refreshPlatformSurfaceFromStore();
    return;
  }
  const includeDrafts = document.querySelector("#report-include-drafts")?.checked || false;
  try {
    if (container) {
      container.innerHTML = '<article class="engine-empty"><strong>Generating executive report...</strong><p>Compiling Organization Profile, assessment coverage, findings, evidence, KPI gaps, recommendations, roadmap, and value estimates.</p></article>';
    }
    const query = `?projectId=${encodeURIComponent(projectId)}${includeDrafts ? "&includeDrafts=true" : ""}`;
    executiveReportState = await apiRequest(`/api/executive-report${query}`);
    setState('executive', 'report', executiveReportState ?? null);
    refreshOwnerSurfaceFromStore();
    refreshConsultantSurfaceFromStore();
    refreshPlatformSurfaceFromStore();
  } catch (error) {
    executiveReportState = null;
    setState('executive', 'report', executiveReportState ?? null);
    if (container) {
      container.innerHTML = `<article class="engine-empty"><strong>Executive report unavailable</strong><p>${escapeHtml(error.message)}</p></article>`;
    }
  }
}

async function updateFinding(id, payload) {
  await apiRequest(`/api/findings/${encodeURIComponent(id)}`, {
    method: "PATCH",
    body: JSON.stringify(payload)
  });

  syncFindingFeedback(id, payload);
  const displayStatus = payload.status ? normalizeReviewStatus(payload.status) : null;

  if (assessmentEngineState?.findings) {
    const finding = assessmentEngineState.findings.find((item) => String(item.id) === String(id));
    if (finding && displayStatus) finding.status = displayStatus;
    mergeState('assessment', { findings: assessmentEngineState.findings });
  }

  if (window.__platformState?.findings) {
    const finding = window.__platformState.findings.find((item) => String(item.id) === String(id));
    if (finding && displayStatus) finding.status = displayStatus;
  }

  if (window.__consultantState?.findings) {
    const finding = window.__consultantState.findings.find((item) => String(item.id) === String(id));
    if (finding && displayStatus) finding.status = displayStatus;
  }

  await refreshAssessmentEngine();
  await renderActiveReviewSurfaces();
}

function promptFindingRejectionReason() {
  return new Promise((resolve) => {
    const existing = document.getElementById("finding-rejection-modal");
    if (existing) existing.remove();

    const modal = document.createElement("div");
    modal.id = "finding-rejection-modal";
    modal.style.cssText = "position:fixed;inset:0;background:rgba(0,0,0,0.72);z-index:9999;display:flex;align-items:center;justify-content:center;padding:1.5rem;";
    modal.innerHTML = `
      <div style="width:min(520px,100%);background:#15110B;border:0.5px solid rgba(200,169,110,0.22);border-radius:10px;box-shadow:0 24px 80px rgba(0,0,0,0.45);padding:1.25rem;">
        <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:1rem;margin-bottom:1rem;">
          <div>
            <h3 style="margin:0;color:#E8E4DC;font-size:18px;">Reject finding</h3>
            <p style="margin:6px 0 0;color:rgba(232,228,220,0.55);font-size:13px;line-height:1.45;">Rejected findings stay in the system and train future analysis. Add the reason so the learning signal is useful.</p>
          </div>
          <button type="button" data-rejection-cancel style="background:none;border:none;color:#E8E4DC;font-size:20px;cursor:pointer;">x</button>
        </div>
        <label style="display:block;color:rgba(200,169,110,0.72);font-size:12px;text-transform:uppercase;letter-spacing:0.08em;">
          Why are you rejecting this finding?
          <textarea data-rejection-reason rows="5" style="box-sizing:border-box;width:100%;margin-top:8px;background:rgba(255,255,255,0.04);border:0.5px solid rgba(200,169,110,0.22);border-radius:8px;color:#E8E4DC;padding:10px 12px;font:inherit;line-height:1.45;resize:vertical;" placeholder="Example: Evidence is too weak, duplicates another finding, or misreads the stakeholder signal."></textarea>
        </label>
        <div data-rejection-error style="display:none;color:#E07B5A;font-size:12px;margin-top:8px;">Please enter a rejection reason.</div>
        <div style="display:flex;justify-content:flex-end;gap:10px;margin-top:1rem;">
          <button type="button" data-rejection-cancel style="background:transparent;color:rgba(232,228,220,0.72);border:1px solid rgba(232,228,220,0.18);border-radius:8px;padding:9px 13px;cursor:pointer;">Cancel</button>
          <button type="button" data-rejection-submit style="background:#E07B5A;color:#15110B;border:none;border-radius:8px;padding:9px 13px;font-weight:700;cursor:pointer;">Reject finding</button>
        </div>
      </div>
    `;

    const close = (value) => {
      modal.remove();
      resolve(value);
    };
    modal.querySelectorAll("[data-rejection-cancel]").forEach((button) => {
      button.addEventListener("click", () => close(null));
    });
    modal.addEventListener("click", (event) => {
      if (event.target === modal) close(null);
    });
    modal.querySelector("[data-rejection-submit]")?.addEventListener("click", () => {
      const reason = modal.querySelector("[data-rejection-reason]")?.value.trim() || "";
      if (!reason) {
        const error = modal.querySelector("[data-rejection-error]");
        if (error) error.style.display = "block";
        return;
      }
      close(reason);
    });
    document.body.appendChild(modal);
    modal.querySelector("[data-rejection-reason]")?.focus();
  });
}

async function rejectFindingWithReason(id) {
  const reason = await promptFindingRejectionReason();
  if (!reason) return;
  await updateFinding(id, { status: "rejected", rejectionReason: reason });
}

async function deleteFindingForCleanup(id) {
  const finding = (assessmentEngineState?.findings || []).find((item) => String(item.id) === String(id));
  const title = finding?.title || "this finding";
  const confirmed = window.confirm(`Delete "${title}"?\n\nUse this only for test data cleanup. Rejected findings should normally stay in the system so they train future analysis.`);
  if (!confirmed) return;
  await apiRequest(`/api/findings/${encodeURIComponent(id)}`, {
    method: "DELETE"
  });
  await refreshAssessmentEngine();
}

function syncFindingFeedback(id, payload = {}) {
  const status = String(payload.status || "").toLowerCase();
  let body = null;
  if (status === "approved" || status === "rejected") {
    body = {
      action: status,
      rejection_reason: payload.rejectionReason || payload.rejection_reason || null
    };
  } else if (payload.title !== undefined || payload.description !== undefined) {
    body = {
      action: "edited",
      edited_title: payload.title,
      edited_description: payload.description
    };
  }
  if (!body) return;
  apiRequest(`/api/findings/${encodeURIComponent(id)}/feedback`, {
    method: "POST",
    body: JSON.stringify(body)
  }).catch((error) => {
    console.warn("Finding feedback sync failed:", error);
  });
}

async function updateRecommendation(id, payload) {
  await apiRequest(`/api/recommendations/${encodeURIComponent(id)}`, {
    method: "PATCH",
    body: JSON.stringify(payload)
  });
  const displayStatus = payload.status ? normalizeReviewStatus(payload.status) : null;

  if (assessmentEngineState?.recommendations) {
    const rec = assessmentEngineState.recommendations.find((item) => String(item.id) === String(id));
    if (rec && displayStatus) rec.status = displayStatus;
    mergeState('assessment', {
      recommendations: assessmentEngineState.recommendations
    });
  }

  if (window.__platformState?.recommendations) {
    const rec = window.__platformState.recommendations.find((item) => String(item.id) === String(id));
    if (rec && displayStatus) rec.status = displayStatus;
  }

  if (window.__consultantState?.recommendations) {
    const rec = window.__consultantState.recommendations.find((item) => String(item.id) === String(id));
    if (rec && displayStatus) rec.status = displayStatus;
  }

  await refreshAssessmentEngine();
  await renderActiveReviewSurfaces();
}

async function mergeSelectedFindings(parentFindingId, childFindingIds) {
  await apiRequest("/api/findings/merge", {
    method: "POST",
    body: JSON.stringify({ parentFindingId, childFindingIds })
  });
  await refreshAssessmentEngine();
}

// ── CONSULTANT SHELL CALLBACKS ──────────────────
// Wrapped from inline handlers for consultant shell
// callback bridge. Do not call these directly from
// legacy rendering or other legacy paths.
function currentAssessmentContext() {
  const assessmentSlice = getSlice("assessment") || {};
  const consultantSlice = getSlice("consultant") || {};
  const assessment = assessmentSlice.assessment || assessmentEngineState?.assessment || {};
  const activeConsultantId = consultantSlice.activeEngagementId || window.__consultantState?.activeEngagementId || null;
  const platformProjectId = platformProjectIdFallback();
  return {
    assessmentId: assessmentSlice.activeAssessmentId || assessment.id || assessmentEngineState?.assessment?.id || null,
    projectId: assessment.company_id || assessment.companyId || platformProjectId || activeConsultantId || null
  };
}

function showParticipantFormError(message) {
  const form = document.querySelector("[data-component-participant-form]");
  const fallback = document.querySelector("#assessment-engine-dashboard");
  const text = message || "Unknown error";
  document.querySelectorAll("[data-participant-form-error]").forEach((node) => node.remove());
  const html = `<article data-participant-form-error style="margin-top:12px;background:rgba(224,123,90,0.08);border:0.5px solid rgba(224,123,90,0.35);border-radius:8px;padding:10px 12px;color:#E07B5A;font-size:13px;line-height:1.45;"><strong>Failed to add participant:</strong> ${escapeHtml(text)}</article>`;
  if (form) form.insertAdjacentHTML("beforeend", html);
  else if (fallback) fallback.insertAdjacentHTML("afterbegin", html);
}

async function refreshCurrentAssessmentEngine(projectId = null) {
  const targetProjectId = projectId || currentAssessmentContext().projectId;
  if (targetProjectId) {
    assessmentEngineState = await apiRequest(`/api/assessment-engine?projectId=${encodeURIComponent(targetProjectId)}`);
    mergeState('assessment', {
      assessment:                assessmentEngineState?.assessment ?? null,
      activeAssessmentId:        assessmentEngineState?.assessment?.id ?? null,
      blueprint:                 assessmentEngineState?.blueprint ?? assessmentEngineState?.assessmentBlueprint ?? null,
      participants:              assessmentEngineState?.assessmentParticipants ?? [],
      sessions:                  assessmentEngineState?.sessions ?? [],
      findings:                  assessmentEngineState?.findings ?? [],
      evidence:                  assessmentEngineState?.evidence ?? [],
      clusters:                  assessmentEngineState?.clusters ?? [],
      recommendations:           assessmentEngineState?.recommendations ?? [],
      roadmapItems:              assessmentEngineState?.roadmapItems ?? [],
      coverage:                  assessmentEngineState?.participantCoverage ?? null,
      progressMemory:            assessmentEngineState?.progressMemory ?? null,
      companyProfile:            assessmentEngineState?.companyProfile ?? null,
      projectContextIntake:      assessmentEngineState?.projectContextIntake ?? null,
      kpiGaps:                   assessmentEngineState?.kpiGaps ?? []
    });
    refreshOwnerSurfaceFromStore();
    refreshConsultantSurfaceFromStore();
    refreshManagerSurfaceFromStore();
    refreshPlatformSurfaceFromStore();
    return assessmentEngineState;
  }
  await refreshAssessmentEngine();
  return assessmentEngineState;
}

async function consultantAddParticipant(data = {}) {
  const { assessmentId, projectId } = currentAssessmentContext();
  if (!assessmentId) {
    showParticipantFormError("Assessment is not loaded.");
    return;
  }
  const submitParticipant = async (extra = {}) => apiRequest(`/api/assessments/${encodeURIComponent(assessmentId)}/participants`, {
    method: "POST",
    body: JSON.stringify({ ...data, ...extra })
  });
  try {
    await submitParticipant();
    await refreshCurrentAssessmentEngine(projectId);
  } catch (error) {
    const message = error.message || "";
    if (error.error === "email_name_mismatch") {
      const email = data.email || error.email || "This email";
      const existingName = error.existingName || "another participant";
      const newName = String(data.full_name || data.fullName || `${data.first_name || data.firstName || ""} ${data.last_name || data.lastName || ""}`.trim() || "this participant");
      if (window.confirm(`Warning: ${email} is already registered to ${existingName}.\n\nYou are adding it for ${newName}.\n\nAre you sure this is correct?`)) {
        await submitParticipant({ allowDuplicate: true });
        await refreshCurrentAssessmentEngine(projectId);
        return;
      }
      showParticipantFormError(message);
      return;
    }
    if ((error.error === "duplicate_same_role" || /already added|already exists/i.test(message)) && window.confirm(`${message}\n\nAdd anyway?`)) {
      await submitParticipant({ allowDuplicate: true });
      await refreshCurrentAssessmentEngine(projectId);
      return;
    }
    showParticipantFormError(message);
  }
}

async function consultantEditParticipant(id, data = null) {
  let participant = (assessmentEngineState?.assessmentParticipants || []).find((item) => String(item.participant_id) === String(id));
  if (!participant) {
    participant = (window.__platformState?.participants || []).find((item) => String(item.participant_id || item.id) === String(id));
  }
  if (!participant) {
    try {
      const result = await apiRequest(`/api/participants/${encodeURIComponent(id)}`);
      participant = result.participant || result;
    } catch (e) {
      console.error("[EDIT] Failed to fetch participant:", e);
      return;
    }
  }
  if (!participant) {
    console.error("[EDIT] Participant not found:", id);
    return;
  }
  if (!data) {
    showParticipantEditModal(participant);
    return;
  }
  const payload = {
    name: data.name ?? data.full_name ?? participant.full_name,
    full_name: data.name ?? data.full_name ?? participant.full_name,
    email: data.email ?? participant.email,
    role: data.role ?? data.stakeholder_role_id ?? participant.stakeholder_role_id,
    stakeholder_role_id: data.role ?? data.stakeholder_role_id ?? participant.stakeholder_role_id,
    group: data.group ?? data.stakeholder_group_id ?? participant.stakeholder_group_id
  };
  const result = await apiRequest(`/api/participants/${encodeURIComponent(participant.participant_id)}`, {
    method: "PATCH",
    body: JSON.stringify(payload)
  });
  await refreshAssessmentEngine();
  showActionToast(`${participantDisplayName(result.participant || participant)} updated.`);
  return result;
}

async function consultantDeactivateParticipant(id) {
  const participant = (assessmentEngineState?.assessmentParticipants || []).find((item) => String(item.participant_id) === String(id));
  const name = participantDisplayName(participant || {});
  if (!window.confirm(`Deactivate ${name}?\nThey will no longer be able to access their session.`)) return;
  await apiRequest(`/api/participants/${encodeURIComponent(id)}`, {
    method: "PATCH",
    body: JSON.stringify({ status: "inactive" })
  });
  await refreshAssessmentEngine();
  showActionToast(`${name} deactivated.`);
}

async function consultantCreateSession(participantId) {
  await apiRequest(`/api/participants/${encodeURIComponent(participantId)}/create-session`, { method: "POST" });
  await refreshAssessmentEngine();
}

function consultantViewSession(sessionId) {
  window.alert(`Session ID: ${sessionId}`);
}

function platformViewSession(sessionId) {
  if (!sessionId) return;
  window.open(`/session/${encodeURIComponent(sessionId)}`, "_blank");
}

async function consultantGenerateLink(participantId) {
  const participant = (assessmentEngineState?.assessmentParticipants || []).find((item) => String(item.participant_id) === String(participantId));
  const name = participantDisplayName(participant || {});
  const hasExistingLink = Boolean(participant?.active_token_expires_at || participantAccessLinks[participantId]);
  if (hasExistingLink && !window.confirm(`Regenerate magic link for ${name}?\nOld link will stop working.`)) return null;
  const payload = await apiRequest(`/api/participants/${encodeURIComponent(participantId)}/regenerate-link`, { method: "POST" });
  if (payload.access_link) {
    participantAccessLinks[participantId] = payload.access_link;
    saveParticipantAccessLinks();
    await navigator.clipboard?.writeText(payload.access_link).catch(() => {});
    showParticipantLinkModal(participant || { participant_id: participantId }, payload.access_link);
  }
  await refreshAssessmentEngine();
  showActionToast(`Magic link ready for ${name}.`);
  return payload;
}

function consultantCopyLink(link) {
  return navigator.clipboard?.writeText(link).catch(() => {});
}

function activeAssessmentId() {
  return currentAssessmentContext().assessmentId || assessmentEngineState?.activeAssessmentId || null;
}

function isParticipantScope(value) {
  return ["all", "not_invited", "incomplete", "required", "recommended", "invited"].includes(String(value || ""));
}

async function sendParticipantInvitation(idOrScope, opts = {}) {
  let payload;
  if (isParticipantScope(idOrScope)) {
    const assessmentId = activeAssessmentId();
    if (!assessmentId) throw new Error("Assessment is not loaded.");
    payload = await apiRequest(`/api/assessments/${encodeURIComponent(assessmentId)}/participants/send-invitations`, {
      method: "POST",
      body: JSON.stringify({ scope: idOrScope, ...opts })
    });
  } else {
    payload = await apiRequest(`/api/participants/${encodeURIComponent(idOrScope)}/send-invitation`, {
      method: "POST",
      body: JSON.stringify(opts)
    });
  }
  await refreshAssessmentEngine();
  if (!isParticipantScope(idOrScope)) {
    const participant = payload.participant || (assessmentEngineState?.assessmentParticipants || []).find((item) => String(item.participant_id) === String(idOrScope));
    showActionToast(`Invitation sent to ${participant?.email || "participant"}`);
  }
  return payload;
}

async function sendParticipantReminder(idOrScope, opts = {}) {
  let payload;
  if (isParticipantScope(idOrScope)) {
    const assessmentId = activeAssessmentId();
    if (!assessmentId) throw new Error("Assessment is not loaded.");
    payload = await apiRequest(`/api/assessments/${encodeURIComponent(assessmentId)}/reminders/bulk-send`, {
      method: "POST",
      body: JSON.stringify({ scope: idOrScope, ...opts })
    });
  } else {
    payload = await apiRequest(`/api/participants/${encodeURIComponent(idOrScope)}/send-reminder`, {
      method: "POST",
      body: JSON.stringify(opts)
    });
  }
  await refreshAssessmentEngine();
  if (!isParticipantScope(idOrScope)) {
    const participant = payload.participant || (assessmentEngineState?.assessmentParticipants || []).find((item) => String(item.participant_id) === String(idOrScope));
    showActionToast(`Reminder sent to ${participant?.email || "participant"}`);
  }
  return payload;
}

async function previewParticipantInvitation(id) {
  const data = await apiRequest(`/api/participants/${encodeURIComponent(id)}/invitation-preview`, {
    method: "GET"
  });
  showEmailPreviewModal(
    data.email?.subject || data.subject || "Assessment Invitation",
    data.email?.body || data.body || data.html || data.content || ""
  );
  return data;
}

async function previewParticipantReminder(id) {
  const data = await apiRequest(`/api/participants/${encodeURIComponent(id)}/preview-reminder`, {
    method: "GET"
  });
  showEmailPreviewModal(
    data.email?.subject || data.subject || "Assessment Reminder",
    data.email?.body || data.body || data.html || data.content || ""
  );
  return data;
}

function showEmailPreviewModal(subject, body) {
  const existing = document.getElementById("email-preview-modal");
  if (existing) existing.remove();

  const modal = document.createElement("div");
  modal.id = "email-preview-modal";
  modal.style.cssText = `
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.7);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
  `;
  const bodyText = String(body || "");
  const isHtml = /<([a-z][\s\S]*?)>/i.test(bodyText);
  modal.innerHTML = `
    <div style="
      background: #111109;
      border: 1px solid rgba(200,169,110,0.3);
      border-radius: 12px;
      padding: 1.5rem;
      max-width: 720px;
      width: 90%;
      max-height: 80vh;
      overflow-y: auto;
      color: #E8E4DC;
    ">
      <div style="
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 1rem;
        margin-bottom: 1rem;
      ">
        <h3 style="
          font-size: 15px;
          font-weight: 500;
          color: #C8A96E;
          margin: 0;
        ">${escapeHtml(subject)}</h3>
        <button
          type="button"
          data-email-preview-close
          style="
            background: none;
            border: none;
            color: #E8E4DC;
            cursor: pointer;
            font-size: 18px;
          "
        >x</button>
      </div>
      ${isHtml ? `
        <iframe
          title="Email preview"
          sandbox=""
          srcdoc="${escapeHtml(bodyText)}"
          style="
            width: 100%;
            min-height: 520px;
            border: 1px solid rgba(200,169,110,0.18);
            border-radius: 8px;
            background: #fff;
          "
        ></iframe>
      ` : `
        <div style="
          font-size: 13px;
          line-height: 1.6;
          color: rgba(232,228,220,0.8);
          white-space: pre-wrap;
        ">${escapeHtml(bodyText)}</div>
      `}
    </div>
  `;
  modal.querySelector("[data-email-preview-close]")?.addEventListener("click", () => modal.remove());
  modal.addEventListener("click", (event) => {
    if (event.target === modal) modal.remove();
  });
  document.body.appendChild(modal);
}

function showActionToast(message, type = "success") {
  const toast = document.createElement("div");
  toast.style.cssText = `
    position: fixed;
    right: 18px;
    bottom: 18px;
    z-index: 10000;
    max-width: 360px;
    background: ${type === "error" ? "rgba(224,123,90,0.96)" : type === "warning" ? "rgba(200,169,110,0.96)" : "rgba(107,184,138,0.96)"};
    color: #111109;
    border-radius: 10px;
    padding: 12px 14px;
    font-size: 13px;
    font-weight: 600;
    box-shadow: 0 16px 40px rgba(0,0,0,0.35);
  `;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 4000);
}

function participantDisplayName(participant = {}) {
  return participant.full_name || participant.name || participant.email || "participant";
}

function currentParticipantRoleOptions(participant = {}) {
  const fallback = [
    ["owner", "Owner"],
    ["ceo", "CEO / Managing Director"],
    ["operations_manager", "Operations Manager"],
    ["branch_manager", "Branch Manager"],
    ["dispatcher", "Dispatcher / Customer Service Coordinator"],
    ["technician", "Technician / Field Service Technician"],
    ["warehouse_manager", "Warehouse Manager"],
    ["inventory_coordinator", "Inventory Coordinator"],
    ["finance_manager", "Finance Manager"],
    ["accountant", "Accountant"],
    ["it_manager", "IT Manager / Systems Administrator"],
    ["hr_manager", "HR / Workforce Manager"],
    ["sales_manager", "Sales Manager"],
    ["sales_representative", "Sales Representative / Account Manager"],
    ["fleet_customer", "Fleet Customer"],
    ["dealer_customer", "Dealer Customer"],
    ["retail_customer", "Retail Customer"],
    ["service_partner", "Service Partner"],
    ["dealer_partner", "Dealer Partner"],
    ["supplier", "Supplier"]
  ].map(([id, name]) => ({ id, name }));
  const coverage = assessmentEngineState?.participantCoverage || assessmentEngineState?.coverage || {};
  const fromCoverage = [
    ...(coverage.required_roles || []),
    ...(coverage.recommended_roles || []),
    ...(coverage.optional_roles || [])
  ].map((role) => ({
    id: role.id || role.role_id || role.stakeholder_role_id,
    name: role.name || role.role_name || role.label || role.id
  })).filter((role) => role.id);
  const merged = [...fromCoverage, ...fallback];
  if (participant.stakeholder_role_id && !merged.some((role) => String(role.id) === String(participant.stakeholder_role_id))) {
    merged.unshift({ id: participant.stakeholder_role_id, name: participant.stakeholder_role_name || participant.stakeholder_role_id });
  }
  const seen = new Set();
  return merged.filter((role) => {
    if (seen.has(role.id)) return false;
    seen.add(role.id);
    return true;
  });
}

function showParticipantLinkModal(participant, accessLink) {
  const existing = document.getElementById("participant-link-modal");
  if (existing) existing.remove();
  const modal = document.createElement("div");
  modal.id = "participant-link-modal";
  modal.style.cssText = "position:fixed;inset:0;background:rgba(0,0,0,0.72);z-index:9999;display:flex;align-items:center;justify-content:center;padding:1.5rem;";
  modal.innerHTML = `
    <div style="width:min(640px,100%);background:#111109;border:1px solid rgba(200,169,110,0.25);border-radius:12px;padding:1.25rem;color:#E8E4DC;">
      <div style="display:flex;justify-content:space-between;gap:1rem;align-items:center;margin-bottom:1rem;">
        <div><p style="margin:0;color:rgba(200,169,110,0.55);font-size:11px;text-transform:uppercase;letter-spacing:0.08em;">Magic Link</p><h3 style="margin:4px 0 0;font-size:18px;">${escapeHtml(participantDisplayName(participant))}</h3></div>
        <button type="button" data-link-modal-close style="background:none;border:none;color:#E8E4DC;font-size:20px;cursor:pointer;">x</button>
      </div>
      <textarea readonly style="width:100%;min-height:96px;background:#1A1A18;border:1px solid rgba(200,169,110,0.25);border-radius:8px;color:#E8E4DC;padding:10px;">${escapeHtml(accessLink || "")}</textarea>
      <div style="display:flex;justify-content:flex-end;gap:10px;margin-top:1rem;">
        <button type="button" data-link-copy style="background:#C8A96E;color:#1A1508;border:none;border-radius:8px;padding:10px 14px;font-weight:600;cursor:pointer;">Copy Link</button>
        <button type="button" data-link-modal-close style="background:transparent;color:rgba(232,228,220,0.7);border:1px solid rgba(232,228,220,0.18);border-radius:8px;padding:10px 14px;cursor:pointer;">Close</button>
      </div>
    </div>
  `;
  modal.querySelectorAll("[data-link-modal-close]").forEach((button) => button.addEventListener("click", () => modal.remove()));
  modal.querySelector("[data-link-copy]")?.addEventListener("click", async () => {
    await navigator.clipboard?.writeText(accessLink || "").catch(() => {});
    showActionToast("Magic link copied.");
  });
  modal.addEventListener("click", (event) => {
    if (event.target === modal) modal.remove();
  });
  document.body.appendChild(modal);
}

function showParticipantEditModal(participant) {
  const existing = document.getElementById("participant-edit-modal");
  if (existing) existing.remove();
  const wrapper = document.createElement("div");
  wrapper.id = "participant-edit-modal";
  wrapper.innerHTML = renderEditParticipantModal(participant, currentParticipantRoleOptions(participant));
  document.body.appendChild(wrapper);
  const modalRoot = wrapper.querySelector("[data-participant-edit-backdrop]");
  const form = wrapper.querySelector("[data-participant-edit-form]");
  const roleSelect = wrapper.querySelector("[data-participant-edit-role]");
  const warning = wrapper.querySelector("[data-participant-role-warning]");
  const originalRole = form?.elements.original_role?.value || "";
  const responseCount = Number(form?.elements.response_count?.value || 0);
  const close = () => wrapper.remove();
  wrapper.querySelectorAll("[data-participant-edit-close]").forEach((button) => button.addEventListener("click", close));
  modalRoot?.addEventListener("click", (event) => {
    if (event.target === modalRoot) close();
  });
  roleSelect?.addEventListener("change", () => {
    if (warning && responseCount > 0 && roleSelect.value !== originalRole) warning.style.display = "block";
  });
  wrapper.querySelector("[data-participant-keep-role]")?.addEventListener("click", () => {
    if (roleSelect) roleSelect.value = originalRole;
    if (warning) warning.style.display = "none";
    if (form) form.dataset.roleChangeConfirmed = "";
  });
  wrapper.querySelector("[data-participant-confirm-role-change]")?.addEventListener("click", () => {
    if (form) {
      form.dataset.roleChangeConfirmed = "true";
      form.requestSubmit();
    }
  });
  form?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const errorEl = wrapper.querySelector("[data-participant-edit-error]");
    const formData = Object.fromEntries(new FormData(form).entries());
    const roleChanged = formData.role && formData.role !== originalRole;
    if (roleChanged && responseCount > 0 && form.dataset.roleChangeConfirmed !== "true") {
      if (warning) warning.style.display = "block";
      return;
    }
    try {
      await consultantEditParticipant(participant.participant_id || participant.id, formData);
      close();
    } catch (error) {
      if (errorEl) {
        errorEl.style.display = "block";
        errorEl.textContent = error.message || "Participant could not be saved.";
      }
    }
  });
}

if (typeof window !== "undefined") {
  window.showParticipantEditModal = showParticipantEditModal;
  window.consultantEditParticipant = consultantEditParticipant;
  window.platformEditParticipant = consultantEditParticipant;
  window.consultantDeactivateParticipant = consultantDeactivateParticipant;
  window.platformDeactivateParticipant = consultantDeactivateParticipant;
  window.sendParticipantInvitation = sendParticipantInvitation;
  window.sendParticipantReminder = sendParticipantReminder;
  window.previewParticipantInvitation = previewParticipantInvitation;
  window.previewParticipantReminder = previewParticipantReminder;
  window.updateRecommendation = updateRecommendation;
  window.refreshAssessmentEngine = refreshAssessmentEngine;
}

async function consultantFindingEdit(findingId, text) {
  if (text !== undefined) return updateFinding(findingId, { content: text });
  const finding = (assessmentEngineState?.findings || []).find((item) => String(item.id) === String(findingId));
  if (!finding) return;
  const title = window.prompt("Edit finding title", finding.title);
  if (title !== null) {
    const description = window.prompt("Edit finding description", finding.description || "");
    await updateFinding(finding.id, { title, description: description ?? finding.description });
  }
}

async function consultantFindingNotes(findingId, notes) {
  if (notes !== undefined) return updateFinding(findingId, { notes });
  const finding = (assessmentEngineState?.findings || []).find((item) => String(item.id) === String(findingId));
  if (!finding) return;
  const analystNotes = window.prompt("Analyst notes", finding.analyst_notes || "");
  if (analystNotes !== null) await updateFinding(finding.id, { analystNotes });
}

async function consultantRecommendationOutcome(id, outcome) {
  if (outcome !== undefined) return updateRecommendation(id, { outcome });
  const recommendation = (assessmentEngineState?.recommendations || []).find((item) => String(item.id) === String(id));
  if (!recommendation) return;
  const actualValue = window.prompt("Actual annual value delivered", recommendation.actual_value ?? "");
  if (actualValue === null) return;
  const actualTimeSavings = window.prompt("Actual annual hours saved", recommendation.actual_time_savings ?? "");
  if (actualTimeSavings === null) return;
  const actualCostSavings = window.prompt("Actual annual cost savings", recommendation.actual_cost_savings ?? "");
  if (actualCostSavings === null) return;
  const actualOutcome = window.prompt("Actual outcome achieved", recommendation.actual_outcome || "");
  if (actualOutcome === null) return;
  await updateRecommendation(recommendation.id, {
    actualValue: actualValue === "" ? null : Number(actualValue),
    actualTimeSavings: actualTimeSavings === "" ? null : Number(actualTimeSavings),
    actualCostSavings: actualCostSavings === "" ? null : Number(actualCostSavings),
    actualOutcome,
    status: recommendation.status === "Completed" ? "Completed" : recommendation.status
  });
}

async function consultantRecommendationNotes(id, notes) {
  if (notes !== undefined) return updateRecommendation(id, { notes });
  const recommendation = (assessmentEngineState?.recommendations || []).find((item) => String(item.id) === String(id));
  if (!recommendation) return;
  const analystNotes = window.prompt("Recommendation review notes", recommendation.analyst_notes || "");
  if (analystNotes !== null) await updateRecommendation(recommendation.id, { analystNotes });
}

async function consultantGenerateSnapshot() {
  const projectId = platformProjectIdFallback();
  if (!projectId) return;
  await apiRequest("/api/progress-snapshot", {
    method: "POST",
    body: JSON.stringify({ projectId, regenerate: false })
  });
  await refreshCurrentAssessmentEngine(projectId);
}

async function consultantRegenerateSnapshot() {
  const projectId = platformProjectIdFallback();
  if (!projectId) return;
  await apiRequest("/api/progress-snapshot", {
    method: "POST",
    body: JSON.stringify({ projectId, regenerate: true })
  });
  await refreshCurrentAssessmentEngine(projectId);
}

function consultantPrintReport() {
  window.print();
}

function exportReport(type = "full-report") {
  const projectId = platformProjectIdFallback();
  if (!projectId) return null;
  const endpoint = type === "executive-summary"
    ? "/api/reports/executive-summary"
    : "/api/reports/full-report";
  const url = `${endpoint}?projectId=${encodeURIComponent(projectId)}`;
  window.open(url, "_blank", "noopener");
  return url;
}

async function consultantMarkDelivered() {
  const assessmentId = assessmentEngineState?.assessment?.id;
  if (!assessmentId) return;
  await apiRequest(`/api/assessments/${encodeURIComponent(assessmentId)}/deliver`, {
    method: "POST"
  });
  await refreshAssessmentEngine();
}

function consultantMergeCluster(cluster) {
  if (!cluster?.childFindings?.length) return;
  const parent = cluster.childFindings[0];
  const children = cluster.childFindings.slice(1);
  return mergeSelectedFindings(
    parent.id,
    children.map((finding) => finding.id)
  );
}
// ── END CONSULTANT SHELL CALLBACKS ───────────────

function buildConsultantCallbacks() {
  return {
    onApproveFinding: (id) =>
      updateFinding(id, { status: 'approved' }),
    onRejectFinding: (id) =>
      rejectFindingWithReason(id),
    onEditFinding: (id, text) =>
      consultantFindingEdit(id, text),
    onFindingNotes: (id, notes) =>
      consultantFindingNotes(id, notes),
    onMergeFindings: (ids) =>
      mergeSelectedFindings(ids[0], ids.slice(1)),
    onApproveRecommendation: (id) =>
      updateRecommendation(id, { status: 'approved' }),
    onRejectRecommendation: (id) =>
      updateRecommendation(id, { status: 'rejected' }),
    onRecommendationStatus: (id, status) =>
      updateRecommendation(id, { status }),
    onRecommendationNotes: (id, notes) =>
      consultantRecommendationNotes(id, notes),
    onTrackOutcome: (id, outcome) =>
      consultantRecommendationOutcome(id, outcome),
    onAddParticipant: (data) =>
      consultantAddParticipant(data),
    onEditParticipant: (id, data) =>
      consultantEditParticipant(id, data),
    onDeactivateParticipant: (id) =>
      consultantDeactivateParticipant(id),
    onCreateSession: (participantId) =>
      consultantCreateSession(participantId),
    onViewSession: (sessionId) =>
      consultantViewSession(sessionId),
    onGenerateLink: (participantId) =>
      consultantGenerateLink(participantId),
    onCopyLink: (link) =>
      consultantCopyLink(link),
    onPreviewInvite: (id) =>
      previewParticipantInvitation(id),
    onSendInvite: (id, opts) =>
      sendParticipantInvitation(id, opts),
    onPreviewReminder: (id) =>
      previewParticipantReminder(id),
    onSendReminder: (id, opts) =>
      sendParticipantReminder(id, opts),
    onDownloadTemplate: () =>
      downloadAssessmentParticipantTemplate(),
    onPreviewUpload: (file) =>
      previewAssessmentParticipantUpload(file),
    onConfirmImport: () =>
      importAssessmentParticipantPreview(),
    onDownloadErrors: () =>
      downloadAssessmentParticipantErrorReport(),
    onCreateSessionsForImported: () =>
      createSessionsForUploadedParticipants(),
    onFileSelected: (file) =>
      previewAssessmentParticipantUpload(file),
    onGenerateSnapshot: () =>
      consultantGenerateSnapshot(),
    onRegenerateSnapshot: () =>
      consultantRegenerateSnapshot(),
    onGenerateReport: () =>
      refreshExecutiveReport(),
    onToggleReportSection: (key, val) => {},
    onPrint: () =>
      consultantPrintReport(),
    onExportReport: (type) =>
      exportReport(type),
    onMarkDelivered: () =>
      consultantMarkDelivered(),
    onMergeCluster: (cluster) =>
      consultantMergeCluster(cluster)
  };
}

function buildManagerCallbacks() {
  return {
    onAddParticipant: (data) =>
      consultantAddParticipant(data),
    onEditParticipant: (id, data) =>
      consultantEditParticipant(id, data),
    onDeactivateParticipant: (id) =>
      consultantDeactivateParticipant(id),
    onCreateSession: (participantId) =>
      consultantCreateSession(participantId),
    onViewSession: (sessionId) =>
      consultantViewSession(sessionId),
    onGenerateLink: (participantId) =>
      consultantGenerateLink(participantId),
    onCopyLink: (link) =>
      consultantCopyLink(link),
    onPreviewInvite: (id) =>
      previewParticipantInvitation(id),
    onSendInvite: (id, opts) =>
      sendParticipantInvitation(id, opts),
    onPreviewReminder: (id) =>
      previewParticipantReminder(id),
    onSendReminder: (id, opts) =>
      sendParticipantReminder(id, opts),
    onDownloadTemplate: () =>
      downloadAssessmentParticipantTemplate(),
    onPreviewUpload: (file) =>
      previewAssessmentParticipantUpload(file),
    onConfirmImport: () =>
      importAssessmentParticipantPreview(),
    onDownloadErrors: () =>
      downloadAssessmentParticipantErrorReport(),
    onCreateSessionsForImported: () =>
      createSessionsForUploadedParticipants(),
    onFileSelected: (file) =>
      previewAssessmentParticipantUpload(file),
    onBulkSendInvites: () =>
      sendParticipantInvitationsBulk(),
    onInviteScopeChange: (scope) => {},
    onBulkSendReminders: () =>
      sendParticipantRemindersBulk(),
    onReminderScopeChange: (scope) => {},
    onNotifyConsultant: () => {}
  };
}

// ── PLATFORM SHELL CALLBACKS ─────────────────
async function refreshPlatformCommandCenter() {
  try {
    platformCommandCenterState = await apiRequest("/api/platform-command-center");
    platformCommandCenterError = "";
  } catch (error) {
    platformCommandCenterState = null;
    platformCommandCenterError = error.message;
  }
  mergeState("platform", {
    metrics: platformCommandCenterState ?? null,
    commandCenterError: platformCommandCenterError ?? null,
    classificationFilter: platformClassificationFilter ?? null
  });
  refreshPlatformSurfaceFromStore();
}

function platformOpenOrganization(projectId, view = "dashboard") {
  const project = assessmentProjects.find((item) => String(item.id) === String(projectId));
  if (!project) return;
  openProjectWorkspace(project);
  surveyInvites = [];
  responses = [];
  projectParticipants = [];
  projectContextIntake = null;
  saveProjectContextIntake();
  setActiveView(view || "dashboard");
  loadDatabaseState();
}

function platformCreateOrganization() {
  document.querySelector("#project-company-name")?.focus();
}

async function platformSaveUser(data = {}) {
  const email = normalizeEmail(data.email || "");
  if (!email) return;
  const projectId = platformProjectIdFallback();
  try {
    const payload = await apiRequest("/api/users", {
      method: "POST",
      body: JSON.stringify({
        name: data.name || "",
        email,
        role: data.role || "participant",
        ...(data.password ? { password: data.password } : {}),
        projectId: data.projectId || projectId
      })
    });
    storePlatformUser(payload.user);
    mergeState("platform", { users: platformUsers ?? {} });
    refreshPlatformSurfaceFromStore();
    document.querySelector("#share-box").innerHTML = `<strong>User saved</strong><p>${email} has ${data.role} access for the selected project. Use Send Credentials when ready.</p>`;
  } catch (error) {
    document.querySelector("#share-box").innerHTML = `<strong>User save failed</strong><p>${error.message}</p>`;
  }
}

function platformCreateUser() {
  const existing = document.getElementById("create-user-modal");
  if (existing) {
    existing.remove();
    return;
  }
  const platform = getSlice("platform") || {};
  const modalProjects = Array.isArray(platform.projects) && platform.projects.length
    ? platform.projects
    : (Array.isArray(assessmentProjects) ? assessmentProjects : []);
  const organizationOptions = [
    '<option value="">Leave unassigned</option>',
    ...modalProjects.map((project) => {
      const label = project.clientDisplayName || project.name || project.organizationName || "Unnamed organization";
      return `<option value="${escapeHtml(project.id || "")}">${escapeHtml(label)}</option>`;
    })
  ].join("");

  const modal = document.createElement("div");
  modal.id = "create-user-modal";
  modal.style.cssText = `
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.7);
    z-index: 9999;
    display: flex; align-items: center;
    justify-content: center;
    padding: 1.5rem;
  `;

  modal.innerHTML = `
    <div style="
      background: #111109;
      border: 0.5px solid rgba(200,169,110,0.25);
      border-radius: 16px;
      padding: 1.75rem;
      width: 100%; max-width: 440px;
      font-family: sans-serif;
    ">
      <div style="
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 1.5rem;
      ">
        <div>
          <div style="
            font-size: 16px; font-weight: 500;
            color: #E8E4DC;
          ">New user</div>
          <div style="
            font-size: 12px;
            color: rgba(200,169,110,0.5);
            margin-top: 2px;
          ">Create a platform user. Org assignment happens separately.</div>
        </div>
        <button id="create-user-close" style="
          background: none; border: none;
          color: rgba(232,228,220,0.4);
          cursor: pointer; font-size: 20px;
          padding: 4px; line-height: 1;
        ">x</button>
      </div>

      <div style="display: grid; gap: 14px;">
        <div>
          <div style="
            font-size: 11px; text-transform: uppercase;
            letter-spacing: 0.05em;
            color: rgba(232,228,220,0.35);
            margin-bottom: 5px;
          ">Full name</div>
          <input id="new-user-name" type="text"
            placeholder="e.g. Ahmet Yilmaz"
            style="
              width: 100%; background: #1a1a18;
              border: 0.5px solid rgba(200,169,110,0.3);
              border-radius: 8px;
              padding: 9px 12px; color: #E8E4DC;
              font-size: 13px; outline: none;
            " />
        </div>

        <div>
          <div style="
            font-size: 11px; text-transform: uppercase;
            letter-spacing: 0.05em;
            color: rgba(232,228,220,0.35);
            margin-bottom: 5px;
          ">Email</div>
          <input id="new-user-email" type="email"
            placeholder="ahmet@company.com"
            style="
              width: 100%; background: #1a1a18;
              border: 0.5px solid rgba(200,169,110,0.3);
              border-radius: 8px;
              padding: 9px 12px; color: #E8E4DC;
              font-size: 13px; outline: none;
            " />
        </div>

        <div>
          <div style="
            font-size: 11px; text-transform: uppercase;
            letter-spacing: 0.05em;
            color: rgba(232,228,220,0.35);
            margin-bottom: 5px;
          ">Role</div>
          <select id="new-user-role" style="
            width: 100%; background: #1a1a18;
            border: 0.5px solid rgba(200,169,110,0.3);
            border-radius: 8px;
            padding: 9px 12px; color: #E8E4DC;
            font-size: 13px; outline: none;
            appearance: auto;
          ">
            <option value="consultant">Consultant</option>
            <option value="company_owner">Company Owner</option>
            <option value="assessment_manager">Assessment Manager</option>
            <option value="platform_owner">Platform Owner</option>
          </select>
        </div>

        <div id="new-user-org-wrap">
          <div style="
            font-size: 11px; text-transform: uppercase;
            letter-spacing: 0.05em;
            color: rgba(232,228,220,0.35);
            margin-bottom: 5px;
          ">Assign to organization (optional)</div>
          <select id="new-user-org" style="
            width: 100%; background: #1a1a18;
            border: 0.5px solid rgba(200,169,110,0.3);
            border-radius: 8px;
            padding: 9px 12px; color: #E8E4DC;
            font-size: 13px; outline: none;
            appearance: auto;
          ">
            ${organizationOptions}
          </select>
        </div>

        <div>
          <div style="
            font-size: 11px; text-transform: uppercase;
            letter-spacing: 0.05em;
            color: rgba(232,228,220,0.35);
            margin-bottom: 5px;
          ">Temporary password</div>
          <input id="new-user-password" type="text"
            placeholder="Auto-generated if blank"
            style="
              width: 100%; background: #1a1a18;
              border: 0.5px solid rgba(200,169,110,0.3);
              border-radius: 8px;
              padding: 9px 12px; color: #E8E4DC;
              font-size: 13px; outline: none;
            " />
          <div style="
            font-size: 11px;
            color: rgba(232,228,220,0.25);
            margin-top: 4px;
          ">User will be prompted to change on first login.</div>
        </div>

        <div id="new-user-error" style="
          display: none;
          background: rgba(224,100,80,0.08);
          border: 0.5px solid rgba(224,100,80,0.35);
          border-radius: 8px;
          padding: 8px 12px; color: #E07B5A;
          font-size: 12px;
        "></div>

        <div style="display: flex; gap: 8px;">
          <button id="new-user-cancel" style="
            flex: 1; padding: 9px;
            font-size: 13px;
            border: 0.5px solid rgba(200,169,110,0.2);
            border-radius: 8px;
            background: transparent;
            color: rgba(232,228,220,0.5);
            cursor: pointer;
          ">Cancel</button>
          <button id="new-user-submit" style="
            flex: 2; padding: 9px;
            font-size: 13px; font-weight: 500;
            border: none; border-radius: 8px;
            background: #C8A96E; color: #1a1608;
            cursor: pointer;
          ">Create user</button>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modal);

  const close = () => modal.remove();
  document.getElementById("create-user-close")?.addEventListener("click", close);
  document.getElementById("new-user-cancel")?.addEventListener("click", close);
  modal.addEventListener("click", (event) => {
    if (event.target === modal) close();
  });

  const roleSelect = document.getElementById("new-user-role");
  const orgWrap = document.getElementById("new-user-org-wrap");
  const syncOrgVisibility = () => {
    if (!orgWrap) return;
    orgWrap.style.display = roleSelect?.value === "consultant" ? "block" : "none";
  };
  roleSelect?.addEventListener("change", syncOrgVisibility);
  syncOrgVisibility();

  document.getElementById("new-user-submit")?.addEventListener("click", async () => {
    const name = document.getElementById("new-user-name")?.value.trim() || "";
    const email = normalizeEmail(document.getElementById("new-user-email")?.value || "");
    const role = document.getElementById("new-user-role")?.value || "consultant";
    const orgId = document.getElementById("new-user-org")?.value || "";
    const password = document.getElementById("new-user-password")?.value.trim() || "";
    const errorEl = document.getElementById("new-user-error");
    const submitBtn = document.getElementById("new-user-submit");

    if (!name) {
      errorEl.textContent = "Full name is required.";
      errorEl.style.display = "block";
      return;
    }
    if (!email) {
      errorEl.textContent = "Email is required.";
      errorEl.style.display = "block";
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = "Creating...";
    errorEl.style.display = "none";

    try {
      await apiRequest("/api/users", {
        method: "POST",
        body: JSON.stringify({
          name,
          email,
          role,
          ...(password ? { password } : {}),
          ...(role === "consultant" && orgId ? { projectId: orgId } : {})
        })
      });

      modal.remove();
      await refreshPlatformUsers();
    } catch (error) {
      errorEl.textContent = error.message || "Failed to create user.";
      errorEl.style.display = "block";
      submitBtn.disabled = false;
      submitBtn.textContent = "Create user";
    }
  });

  setTimeout(() => {
    document.getElementById("new-user-name")?.focus();
  }, 50);
}

function platformEditUser(userId) {
  const user = platformUsers[userId]
    || Object.values(platformUsers).find((item) => String(item.id) === String(userId));
  if (!user) return;

  const existing = document.getElementById("edit-user-modal");
  if (existing) existing.remove();

  const platform = getSlice("platform") || {};
  const projects = Array.isArray(platform.projects) && platform.projects.length
    ? platform.projects
    : (Array.isArray(assessmentProjects) ? assessmentProjects : []);
  const orgOptions = projects.map((project) => {
    const selected = String(user.projectId || "") === String(project.id || "") ? "selected" : "";
    const label = project.clientDisplayName || project.name || project.organizationName || project.id || "Unnamed organization";
    return `<option value="${escapeHtml(project.id || "")}" ${selected}>${escapeHtml(label)}</option>`;
  }).join("");

  const modal = document.createElement("div");
  modal.id = "edit-user-modal";
  modal.style.cssText = `
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.7);
    z-index: 9999;
    display: flex; align-items: center;
    justify-content: center;
    padding: 1.5rem;
  `;

  modal.innerHTML = `
    <div style="
      background: #111109;
      border: 0.5px solid rgba(200,169,110,0.25);
      border-radius: 16px;
      padding: 1.75rem;
      width: 100%; max-width: 440px;
      font-family: sans-serif;
    ">
      <div style="
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 1.5rem;
      ">
        <div>
          <div style="font-size: 16px; font-weight: 500; color: #E8E4DC;">Edit user</div>
          <div style="font-size: 12px; color: rgba(200,169,110,0.5); margin-top: 2px;">${escapeHtml(user.email || "")}</div>
        </div>
        <button id="edit-user-close" style="
          background: none; border: none;
          color: rgba(232,228,220,0.4);
          cursor: pointer; font-size: 20px;
          padding: 4px; line-height: 1;
        ">x</button>
      </div>

      <div style="display: grid; gap: 14px;">
        <div>
          <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: rgba(232,228,220,0.35); margin-bottom: 5px;">Full name</div>
          <input id="edit-user-name" type="text" value="${escapeHtml(user.name || "")}" style="
            width: 100%; background: #1a1a18;
            border: 0.5px solid rgba(200,169,110,0.3);
            border-radius: 8px;
            padding: 9px 12px; color: #E8E4DC;
            font-size: 13px; outline: none;
          " />
        </div>

        <div>
          <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: rgba(232,228,220,0.35); margin-bottom: 5px;">Email</div>
          <input id="edit-user-email" type="email" value="${escapeHtml(user.email || "")}" readonly style="
            width: 100%; background: #151513;
            border: 0.5px solid rgba(200,169,110,0.18);
            border-radius: 8px;
            padding: 9px 12px; color: rgba(232,228,220,0.45);
            font-size: 13px; outline: none;
          " />
        </div>

        <div>
          <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: rgba(232,228,220,0.35); margin-bottom: 5px;">Role</div>
          <select id="edit-user-role" style="
            width: 100%; background: #1a1a18;
            border: 0.5px solid rgba(200,169,110,0.3);
            border-radius: 8px;
            padding: 9px 12px; color: #E8E4DC;
            font-size: 13px; outline: none;
            appearance: auto;
          ">
            <option value="consultant" ${user.role === "consultant" ? "selected" : ""}>Consultant</option>
            <option value="company_owner" ${user.role === "company_owner" ? "selected" : ""}>Company Owner</option>
            <option value="assessment_manager" ${user.role === "assessment_manager" ? "selected" : ""}>Assessment Manager</option>
            <option value="platform_owner" ${user.role === "platform_owner" ? "selected" : ""}>Platform Owner</option>
          </select>
        </div>

        <div id="edit-user-org-wrap" style="display: ${user.role === "consultant" ? "block" : "none"};">
          <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: rgba(232,228,220,0.35); margin-bottom: 5px;">Organization</div>
          <select id="edit-user-org" style="
            width: 100%; background: #1a1a18;
            border: 0.5px solid rgba(200,169,110,0.3);
            border-radius: 8px;
            padding: 9px 12px; color: #E8E4DC;
            font-size: 13px; outline: none;
            appearance: auto;
          ">
            <option value="">Leave unassigned</option>
            ${orgOptions}
          </select>
        </div>

        <div id="edit-user-error" style="
          display: none;
          background: rgba(224,100,80,0.08);
          border: 0.5px solid rgba(224,100,80,0.35);
          border-radius: 8px; padding: 8px 12px;
          color: #E07B5A; font-size: 12px;
        "></div>

        <div style="display: flex; gap: 8px;">
          <button id="edit-user-cancel" style="
            flex: 1; padding: 9px; font-size: 13px;
            border: 0.5px solid rgba(200,169,110,0.2);
            border-radius: 8px; background: transparent;
            color: rgba(232,228,220,0.5);
            cursor: pointer;
          ">Cancel</button>
          <button id="edit-user-submit" style="
            flex: 2; padding: 9px; font-size: 13px;
            font-weight: 500; border: none;
            border-radius: 8px; background: #C8A96E;
            color: #1a1608; cursor: pointer;
          ">Save changes</button>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modal);

  const close = () => modal.remove();
  document.getElementById("edit-user-close")?.addEventListener("click", close);
  document.getElementById("edit-user-cancel")?.addEventListener("click", close);
  modal.addEventListener("click", (event) => {
    if (event.target === modal) close();
  });

  document.getElementById("edit-user-role")?.addEventListener("change", (event) => {
    const orgWrap = document.getElementById("edit-user-org-wrap");
    if (orgWrap) orgWrap.style.display = event.target.value === "consultant" ? "block" : "none";
  });

  document.getElementById("edit-user-submit")?.addEventListener("click", async () => {
    const name = document.getElementById("edit-user-name")?.value.trim() || "";
    const role = document.getElementById("edit-user-role")?.value || "consultant";
    const orgId = document.getElementById("edit-user-org")?.value || "";
    const errorEl = document.getElementById("edit-user-error");
    const submitBtn = document.getElementById("edit-user-submit");

    if (!name) {
      errorEl.textContent = "Full name is required.";
      errorEl.style.display = "block";
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = "Saving...";
    errorEl.style.display = "none";

    try {
      await apiRequest(`/api/users/${encodeURIComponent(userId)}`, {
        method: "PATCH",
        body: JSON.stringify({
          name,
          role,
          projectId: role === "consultant" && orgId ? orgId : undefined
        })
      });
      modal.remove();
      await refreshPlatformUsers();
    } catch (error) {
      errorEl.textContent = error.message || "Failed to save changes.";
      errorEl.style.display = "block";
      submitBtn.disabled = false;
      submitBtn.textContent = "Save changes";
    }
  });
}

function platformAssignConsultant(userId, projectId) {
  const user = Object.values(platformUsers).find((item) => String(item.id || item.email) === String(userId));
  if (!user) return;
  user.projectId = projectId;
  savePlatformUsers();
  mergeState("platform", { users: platformUsers ?? {} });
}

function platformSetClassificationFilter(filter) {
  platformClassificationFilter = filter || "production";
  localStorage.setItem("platformClassificationFilter", platformClassificationFilter);
  setState("platform", "classificationFilter", platformClassificationFilter);
}

async function platformCreateIssue(data = {}) {
  await apiRequest("/api/operations-center/issues", {
    method: "POST",
    body: JSON.stringify({ ...data, source: "manual" })
  });
  await refreshKrbOperationsCenter();
}

async function platformCreateGeneratedIssue(index) {
  const issue = krbOperationsState?.generated_issues?.[Number(index)];
  if (!issue) return;
  await apiRequest("/api/operations-center/issues", { method: "POST", body: JSON.stringify(issue) });
  await refreshKrbOperationsCenter();
}

async function platformResolveIssue(issueId) {
  if (!window.confirm("Resolve this issue?")) return;
  await apiRequest(`/api/operations-center/issues/${encodeURIComponent(issueId)}`, {
    method: "PATCH",
    body: JSON.stringify({ status: "resolved", resolution_notes: "Resolved from Operations Center." })
  });
  await refreshKrbOperationsCenter();
}

async function platformRecordQaRun(data = {}) {
  await apiRequest("/api/operations-center/qa-runs", {
    method: "POST",
    body: JSON.stringify({
      ...data,
      cleanup_status: "not_applicable",
      checks_json: [{ name: "Manual QA record", status: data.status || "passed" }],
      failed_checks_json: data.status === "failed" ? [{ name: "Manual QA record", status: "failed" }] : []
    })
  });
  await refreshKrbOperationsCenter();
}

function platformSelectQuestionBankRole(roleId) {
  activeQuestionBankRole = roleId;
  setState("session", "activeQuestionBankRole", roleId);
}

async function platformGenerateBlueprint() {
  const projectId = platformProjectIdFallback();
  if (!projectId) {
    console.warn("[DERIVE] platformGenerateBlueprint: no active project found");
    return;
  }
  const payload = await apiRequest("/api/assessment-blueprint/generate", {
    method: "POST",
    body: JSON.stringify({ projectId })
  });
  assessmentEngineState = { ...(assessmentEngineState || {}), assessmentBlueprint: payload.blueprint };
  await refreshCurrentAssessmentEngine(projectId);
}

function getAnalysisButtons() {
  return Array.from(document.querySelectorAll('[data-assessment-action="run-analysis"]'));
}

function ensureAnalysisProgressPanel() {
  let panel = document.getElementById("analysis-progress-panel");
  if (panel) return panel;

  const button = getAnalysisButtons()[0];
  if (!button) return null;

  panel = document.createElement("div");
  panel.id = "analysis-progress-panel";
  panel.style.cssText = `
    margin-top: 12px;
    background: rgba(200,169,110,0.07);
    border: 0.5px solid rgba(200,169,110,0.24);
    border-radius: 10px;
    padding: 12px 14px;
    color: #E8E4DC;
  `;
  panel.innerHTML = `
    <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:8px;">
      <div>
        <div data-analysis-progress-title style="font-size:13px;font-weight:500;color:#E8E4DC;">Preparing analysis...</div>
        <div data-analysis-progress-detail style="font-size:12px;color:rgba(232,228,220,0.52);margin-top:2px;">This can take up to a minute.</div>
      </div>
      <div data-analysis-progress-status style="font-size:11px;text-transform:uppercase;letter-spacing:0.06em;color:rgba(200,169,110,0.72);white-space:nowrap;">Running</div>
    </div>
    <div style="height:4px;background:rgba(200,169,110,0.13);border-radius:999px;overflow:hidden;">
      <div data-analysis-progress-fill style="height:100%;width:8%;background:#C8A96E;border-radius:999px;transition:width 0.45s ease;"></div>
    </div>
  `;

  const header = button.closest(".panel-header");
  if (header) {
    header.insertAdjacentElement("afterend", panel);
  } else {
    button.parentElement?.insertAdjacentElement("afterend", panel);
  }
  return panel;
}

function updateAnalysisProgressPanel(state, message, detail) {
  const panel = ensureAnalysisProgressPanel();
  if (!panel) return;

  const title = panel.querySelector("[data-analysis-progress-title]");
  const detailEl = panel.querySelector("[data-analysis-progress-detail]");
  const status = panel.querySelector("[data-analysis-progress-status]");
  const fill = panel.querySelector("[data-analysis-progress-fill]");

  if (title) title.textContent = message;
  if (detailEl) detailEl.textContent = detail || "";
  if (status) status.textContent = state === "success" ? "Complete" : state === "error" ? "Error" : "Running";

  if (state === "success") {
    panel.style.borderColor = "rgba(100,180,100,0.35)";
    panel.style.background = "rgba(100,180,100,0.08)";
    if (status) status.style.color = "rgba(140,210,140,0.9)";
    if (fill) {
      fill.style.background = "#8CD28C";
      fill.style.width = "100%";
    }
  } else if (state === "error") {
    panel.style.borderColor = "rgba(224,100,80,0.35)";
    panel.style.background = "rgba(224,100,80,0.08)";
    if (status) status.style.color = "#E07B5A";
    if (fill) {
      fill.style.background = "#E07B5A";
      fill.style.width = "100%";
    }
  } else {
    panel.style.borderColor = "rgba(200,169,110,0.24)";
    panel.style.background = "rgba(200,169,110,0.07)";
    if (status) status.style.color = "rgba(200,169,110,0.72)";
    if (fill) {
      fill.style.background = "#C8A96E";
      fill.style.width = "8%";
    }
  }
}

function setAnalysisButtonsLoading(isLoading) {
  getAnalysisButtons().forEach((button) => {
    if (!button.dataset.defaultLabel) button.dataset.defaultLabel = button.textContent || "Run Analysis";
    button.disabled = isLoading;
    button.textContent = isLoading ? "Analyzing..." : button.dataset.defaultLabel;
    button.style.opacity = isLoading ? "0.72" : "";
    button.style.cursor = isLoading ? "wait" : "";
  });
}

function startAnalysisProgress() {
  window.clearInterval(analysisProgressTimer);
  let width = 8;
  updateAnalysisProgressPanel(
    "running",
    "Analyzing assessment responses...",
    "AI is reading responses, generating findings, and building recommendations."
  );
  const fill = document.querySelector("#analysis-progress-panel [data-analysis-progress-fill]");
  analysisProgressTimer = window.setInterval(() => {
    width = Math.min(92, width + (width < 55 ? 9 : 4));
    if (fill) fill.style.width = `${width}%`;
  }, 1200);
}

function finishAnalysisProgress(state, message, detail) {
  window.clearInterval(analysisProgressTimer);
  analysisProgressTimer = null;
  updateAnalysisProgressPanel(state, message, detail);
  window.setTimeout(() => {
    document.getElementById("analysis-progress-panel")?.remove();
  }, state === "success" ? 7000 : 10000);
}

async function platformRunAnalysis() {
  const projectId = platformProjectIdFallback();
  if (!projectId) {
    console.warn("[DERIVE] platformRunAnalysis: no active project found");
    return;
  }

  try {
    setAnalysisButtonsLoading(true);
    startAnalysisProgress();

    assessmentEngineState = await apiRequest("/api/assessment-engine/analyze", {
      method: "POST",
      body: JSON.stringify({ projectId })
    });

    await refreshCurrentAssessmentEngine(projectId);
    const findingCount = Number(assessmentEngineState?.findings?.length || 0);
    const recommendationCount = Number(assessmentEngineState?.recommendations?.length || 0);
    finishAnalysisProgress(
      "success",
      "Analysis complete.",
      `${findingCount} findings and ${recommendationCount} recommendations are ready for review.`
    );
  } catch (err) {
    console.error("[DERIVE] Analysis failed:", err.message);
    finishAnalysisProgress(
      "error",
      "Analysis failed.",
      err.message || "Please try again."
    );
  } finally {
    setAnalysisButtonsLoading(false);
  }
}

async function platformCreateAssessment() {
  const projectId = platformProjectIdFallback();
  if (!projectId) {
    console.warn("[DERIVE] platformCreateAssessment: no active project found");
    return;
  }
  await apiRequest("/api/assessment-engine/assessments", {
    method: "POST",
    body: JSON.stringify({
      projectId,
      title: "Operations Manager Assessment MVP"
    })
  });
  await refreshCurrentAssessmentEngine(projectId);
}

function platformGenerateReport() {
  return refreshExecutiveReport();
}

function platformExportReport(type) {
  return exportReport?.(type) ?? null;
}

function platformGenerateSnapshot() {
  return consultantGenerateSnapshot();
}

function platformRegenerateSnapshot() {
  return consultantRegenerateSnapshot();
}

function buildPlatformCallbacks() {
  return {
    sessionToken: currentSessionToken ?? "",
    onRefresh: () => refreshPlatformCommandCenter(),
    onSetClassificationFilter: (filter) => platformSetClassificationFilter(filter),
    onOpenOrganization: (projectId, view) => platformOpenOrganization(projectId, view),
    onOpenReport: (projectId) => platformOpenOrganization(projectId, "executive-report"),
    onOpenAssessmentWorkspace: () => {
      import("./shells/platform.js")
        .then(({ renderPlatformView }) => {
          renderPlatformView("assessment");
        });
    },
    onCreateOrganization: () => platformCreateOrganization(),
    onRunAnalysis: () => platformRunAnalysis(),
    onCreateAssessment: () => platformCreateAssessment(),
    onGenerateBlueprint: () => platformGenerateBlueprint(),
    onGenerateReport: () => platformGenerateReport(),
    onExportReport: (type) => platformExportReport(type),
    onGenerateSnapshot: () => platformGenerateSnapshot(),
    onRegenerateSnapshot: () => platformRegenerateSnapshot(),
    onApproveFinding: (id) => updateFinding(id, { status: "approved" }),
    onRejectFinding: (id) => rejectFindingWithReason(id),
    onDeleteFinding: (id) => deleteFindingForCleanup(id),
    onEditFinding: (id, text) => consultantFindingEdit(id, text),
    onFindingNotes: (id, notes) => consultantFindingNotes(id, notes),
    onMergeFindings: (ids) => mergeSelectedFindings(ids[0], ids.slice(1)),
    onMergeCluster: (cluster) => consultantMergeCluster(cluster),
    onApproveRecommendation: (id) => updateRecommendation(id, { status: "approved" }),
    onRejectRecommendation: (id) => updateRecommendation(id, { status: "rejected" }),
    onRecommendationStatus: (id, status) => updateRecommendation(id, { status }),
    onRecommendationNotes: (id, notes) => consultantRecommendationNotes(id, notes),
    onTrackOutcome: (id, outcome) => consultantRecommendationOutcome(id, outcome),
    onAddParticipant: (data) => consultantAddParticipant(data),
    onEditParticipant: (id, data) => consultantEditParticipant(id, data),
    onDeactivateParticipant: (id) => consultantDeactivateParticipant(id),
    onCreateSession: (participantId) => consultantCreateSession(participantId),
    onViewSession: (sessionId) => platformViewSession(sessionId),
    onGenerateLink: (participantId) => consultantGenerateLink(participantId),
    onCopyLink: (link) => consultantCopyLink(link),
    onPreviewInvite: (id) => previewParticipantInvitation(id),
    onSendInvite: (id, opts) => sendParticipantInvitation(id, opts),
    onPreviewReminder: (id) => previewParticipantReminder(id),
    onSendReminder: (id, opts) => sendParticipantReminder(id, opts),
    onDownloadTemplate: () => downloadAssessmentParticipantTemplate(),
    onPreviewUpload: (file) => previewAssessmentParticipantUpload(file),
    onConfirmImport: () => importAssessmentParticipantPreview(),
    onCreateSessionsForImported: () => createSessionsForUploadedParticipants(),
    onDownloadErrors: () => downloadAssessmentParticipantErrorReport(),
    onFileSelected: (file) => previewAssessmentParticipantUpload(file),
    onBulkSendInvites: () => sendParticipantInvitationsBulk(),
    onBulkSendReminders: () => sendParticipantRemindersBulk(),
    onCreateUser: () => platformCreateUser(),
    onSaveUser: (data) => platformSaveUser(data),
    onAssignProject: (userId, projectId) => platformAssignConsultant(userId, projectId),
    onAssignConsultant: (userId, projectId) => platformAssignConsultant(userId, projectId),
    onEditUser: (userId) => platformEditUser(userId),
    onSendCredentials: (userId) => sendCredentials(userId),
    onSetUserStatus: async (userId, status) => {
      const user = Object.values(platformUsers).find((item) => String(item.id || item.email) === String(userId));
      if (!user) return;
      const payload = await apiRequest(`/api/users/${encodeURIComponent(userId)}`, {
        method: "PATCH",
        body: JSON.stringify({ status, role: user.role, projectId: user.projectId || platformProjectIdFallback() })
      });
      storePlatformUser(payload.user);
      mergeState("platform", { users: platformUsers ?? {} });
      refreshPlatformSurfaceFromStore();
    },
    onRefreshOperations: () => refreshKrbOperationsCenter(),
    onOperationsSectionChange: (section) => {
      krbOperationsSection = section || "overview";
      localStorage.setItem("krbOperationsSection", krbOperationsSection);
      mergeState("operations", { section: krbOperationsSection });
    },
    onCreateIssue: (data) => platformCreateIssue(data),
    onCreateGeneratedIssue: (index) => platformCreateGeneratedIssue(index),
    onResolveIssue: (issueId) => platformResolveIssue(issueId),
    onRecordQaRun: (data) => platformRecordQaRun(data),
    onParticipantAction: (action, participantId) => {
      if (action === "create_session") return consultantCreateSession(participantId);
      if (action === "generate_link") return consultantGenerateLink(participantId);
      if (action === "send_invite") return sendParticipantInvitation(participantId);
      if (action === "send_reminder") return sendParticipantReminder(participantId);
    },
    onLinkAction: (action, tokenId) => {
      if (action === "regenerate") return consultantGenerateLink(tokenId);
    },
    onSelectQuestionBankRole: (roleId) => platformSelectQuestionBankRole(roleId)
  };
}
// ── END PLATFORM SHELL CALLBACKS ─────────────

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function glossaryText(value) {
  return escapeHtml(value || "").replace(/\n/g, "<br>");
}

async function showGlossaryPanel(key) {
  if (!key) return;
  try {
    const data = await apiRequest(`/api/glossary/${encodeURIComponent(key)}`);
    const entry = data.entry;
    if (!entry) return;
    document.querySelectorAll(".glossary-panel").forEach((panel) => panel.remove());
    const panel = document.createElement("div");
    panel.className = "glossary-panel";
    panel.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      width: 320px;
      max-width: calc(100vw - 32px);
      background: #1a1a1a;
      border: 0.5px solid rgba(200,169,110,0.3);
      border-radius: 10px;
      padding: 16px;
      z-index: 9999;
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
    `;
    panel.innerHTML = `
      <div style="display:flex;justify-content:space-between;gap:12px;margin-bottom:8px;">
        <strong style="color:#C8A96E">${escapeHtml(entry.term)}</strong>
        <button data-glossary-close type="button" style="background:none;border:none;color:rgba(232,228,220,0.4);cursor:pointer;font-size:16px;">x</button>
      </div>
      <p style="font-size:12px;color:rgba(232,228,220,0.8);margin:0 0 8px;line-height:1.5;">${glossaryText(entry.definition)}</p>
      ${entry.calculation ? `
        <div style="font-size:11px;color:rgba(200,169,110,0.6);margin-bottom:8px;padding:8px;background:rgba(200,169,110,0.05);border-radius:6px;">
          <strong>How calculated:</strong><br>${glossaryText(entry.calculation)}
        </div>
      ` : ""}
      ${entry.interpretation ? `
        <div style="font-size:11px;color:rgba(232,228,220,0.6);margin-bottom:8px;">
          <strong>What it means:</strong><br>${glossaryText(entry.interpretation)}
        </div>
      ` : ""}
      ${entry.example ? `
        <div style="font-size:11px;color:rgba(232,228,220,0.4);font-style:italic;border-top:0.5px solid rgba(200,169,110,0.1);padding-top:8px;margin-top:4px;">
          ${glossaryText(entry.example)}
        </div>
      ` : ""}
    `;
    document.body.appendChild(panel);
    setTimeout(() => panel.remove(), 8000);
  } catch (error) {
    console.warn("Glossary lookup failed.", error);
  }
}
// DUPLICATED → shared.js — remove from app.js after
// all role modules verified working

function respondentQuestionOptions(question = {}) {
  const normalizeOption = (option) => {
    if (option && typeof option === "object") return String(option.label || option.value || option.text || "");
    return String(option ?? "");
  };
  if (Array.isArray(question.options) && question.options.length) return question.options.map(normalizeOption).filter(Boolean);
  if (typeof question.options === "string") {
    try {
      const parsed = JSON.parse(question.options);
      return Array.isArray(parsed) ? parsed.map(normalizeOption).filter(Boolean) : [];
    } catch {
      return question.options ? [question.options] : [];
    }
  }
  if (question.response_type === "scale_1_5") return ["1", "2", "3", "4", "5"];
  if (question.response_type === "yes_no") return ["Yes", "No"];
  return [];
}
// EXTRACTED → participant.js — verify then remove

function respondentAnswerFor(question = {}) {
  const response = respondentAssessmentState?.responses?.[question.question_id] || {};
  const rawValue = response.answer_value ?? "";
  if (Array.isArray(rawValue)) return rawValue;
  if (rawValue && typeof rawValue === "object") return rawValue;
  return response.answer_text ?? rawValue ?? "";
}
// EXTRACTED → participant.js — verify then remove

function respondentValueHasAnswer(value) {
  if (value === null || value === undefined) return false;
  if (Array.isArray(value)) return value.some((item) => String(item || "").trim());
  return String(value).trim() !== "";
}
// EXTRACTED → participant.js — verify then remove

function respondentRequiredProgress(questions = []) {
  const required = questions.filter((question) => question.required);
  const answered = required.filter((question) => respondentValueHasAnswer(respondentAnswerFor(question)));
  const missingFromServer = new Set(respondentValidationIssues?.missing_required_questions || []);
  return {
    answered: answered.length,
    total: required.length,
    missing: Math.max(0, required.length - answered.length, missingFromServer.size)
  };
}
// EXTRACTED → participant.js — verify then remove

function respondentSections(questions = []) {
  const sections = [];
  questions.forEach((question) => {
    const name = question.section || "Assessment";
    let section = sections.find((item) => item.name === name);
    if (!section) {
      section = { name, total: 0, answered: 0 };
      sections.push(section);
    }
    section.total += 1;
    if (respondentValueHasAnswer(respondentAnswerFor(question))) section.answered += 1;
  });
  return sections;
}
// EXTRACTED → participant.js — verify then remove

function renderRespondentSavedIndicator(question = {}) {
  return respondentValueHasAnswer(respondentAnswerFor(question))
    ? '<small class="respondent-saved-indicator">Saved</small>'
    : '<small class="respondent-saved-indicator pending">Not answered yet</small>';
}
// EXTRACTED → participant.js — verify then remove

function renderRespondentField(question = {}) {
  const id = `respondent-${question.question_id}`;
  const value = respondentAnswerFor(question);
  const options = respondentQuestionOptions(question);
  const responseType = question.response_type || "open_text";
  if (responseType === "multiple_choice") {
    return `
      <div class="respondent-option-grid" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}">
        ${options.map((option) => {
          const checked = Array.isArray(value) && value.includes(option);
          return `<label class="respondent-option"><input class="respondent-field" type="checkbox" value="${escapeHtml(option)}" ${checked ? "checked" : ""}>${escapeHtml(option)}</label>`;
        }).join("")}
      </div>
    `;
  }
  if (responseType === "ranking") {
    const ranked = Array.isArray(value) ? value : [];
    return `
      <div class="respondent-ranking-control" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}">
        <p>Tap options in priority order. Tap again to remove.</p>
        <div class="respondent-ranking-selected">
          ${ranked.length ? ranked.map((option, index) => `<span data-rank-selected="${escapeHtml(option)}">${index + 1}. ${escapeHtml(option)}</span>`).join("") : '<small>No ranking selected yet.</small>'}
        </div>
        <div class="respondent-option-grid">
          ${options.map((option) => {
            const active = ranked.includes(option);
            const rank = ranked.indexOf(option) + 1;
            return `<button class="respondent-rank-option ${active ? "active" : ""}" type="button" data-rank-option="${escapeHtml(option)}">${active ? `${rank}. ` : ""}${escapeHtml(option)}</button>`;
          }).join("")}
        </div>
      </div>
    `;
  }
  if (["single_choice", "scale_1_5", "yes_no"].includes(responseType) || (options.length && responseType === "time_duration")) {
    return `
      <div class="respondent-choice-grid ${responseType === "scale_1_5" ? "respondent-scale-grid" : ""}" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}">
        ${options.map((option) => {
          const checked = String(value) === String(option);
          return `<label class="respondent-choice"><input class="respondent-field" name="${escapeHtml(id)}" type="radio" value="${escapeHtml(option)}" ${checked ? "checked" : ""} ${question.required ? "required" : ""}><span>${escapeHtml(option)}</span></label>`;
        }).join("")}
      </div>
    `;
  }
  if (["numeric", "percentage", "currency", "time_duration"].includes(responseType)) {
    const inputMode = responseType === "time_duration" ? "text" : "decimal";
    const placeholder = responseType === "percentage" ? "0-100" : responseType === "currency" ? "Amount" : responseType === "time_duration" ? "Example: 2 hours" : "Enter a number";
    return `<input class="respondent-field" id="${escapeHtml(id)}" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}" type="text" inputmode="${inputMode}" placeholder="${placeholder}" value="${escapeHtml(value)}" ${question.required ? "required" : ""}>`;
  }
  return `<textarea class="respondent-field" id="${escapeHtml(id)}" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}" rows="5" placeholder="Share the practical reality here..." ${question.required ? "required" : ""}>${escapeHtml(value)}</textarea>`;
}
// EXTRACTED → participant.js — verify then remove

function collectRespondentAnswers() {
  const answers = [];
  document.querySelectorAll("[data-question-card]").forEach((card) => {
    const questionId = card.dataset.questionCard;
    const ranking = card.querySelector(".respondent-ranking-control");
    if (ranking) {
      const selected = [...ranking.querySelectorAll("[data-rank-selected]")].map((item) => item.dataset.rankSelected);
      answers.push({ question_id: questionId, answer_value: selected, answer_text: selected.join(", ") });
      return;
    }
    const multiple = card.querySelector(".respondent-option-grid");
    if (multiple) {
      const selected = [...multiple.querySelectorAll("input:checked")].map((input) => input.value);
      answers.push({ question_id: questionId, answer_value: selected, answer_text: selected.join(", ") });
      return;
    }
    const choice = card.querySelector(".respondent-choice-grid");
    if (choice) {
      const selected = choice.querySelector(".respondent-field:checked")?.value || "";
      answers.push({ question_id: questionId, answer_value: selected, answer_text: selected });
      return;
    }
    const field = card.querySelector(".respondent-field");
    if (!field) return;
    const value = field.value;
    answers.push({ question_id: questionId, answer_value: value, answer_text: value });
  });
  return answers;
}
// EXTRACTED → participant.js — verify then remove

function respondentIssueForQuestion(questionId) {
  const missing = respondentValidationIssues?.missing_required_questions || [];
  const invalid = respondentValidationIssues?.invalid_answers || [];
  const invalidItem = invalid.find((item) => String(item.question_id) === String(questionId));
  if (missing.includes(questionId)) return "This required question needs an answer.";
  if (invalidItem) return invalidItem.reason || "This answer is invalid.";
  return "";
}
// EXTRACTED → participant.js — verify then remove

function ensureRespondentRoot() {
  let root = document.querySelector("#respondent-root");
  if (!root) {
    root = document.createElement("main");
    root.id = "respondent-root";
    root.className = "respondent-shell";
    document.body.appendChild(root);
  }
  return root;
}

function renderRespondentAssessment() {
  document.querySelector("#auth-screen")?.classList.add("hidden");
  document.querySelector(".app-shell")?.classList.add("hidden");
  const root = ensureRespondentRoot();
  if (!respondentAssessmentState) {
    root.innerHTML = `<section class="respondent-card respondent-loading">${renderLoadingSkeleton(screenStateCopy.respondent.loading.title, 3)}</section>`;
    return;
  }
  if (respondentAssessmentState.error) {
    root.innerHTML = `<section class="respondent-card respondent-error">${renderScreenState("respondent", "error", { message: respondentAssessmentState.error })}</section>`;
    return;
  }
  const questions = respondentAssessmentState.questions || [];
  const progress = respondentAssessmentState.progress || {};
  const participant = respondentAssessmentState.participant || {};
  const session = respondentAssessmentState.session || {};
  const assessment = respondentAssessmentState.assessment || {};
  const completed = session.status === "completed" || respondentAssessmentState.token?.completed_at;
  const issueCount = (respondentValidationIssues?.missing_required_questions || []).length + (respondentValidationIssues?.invalid_answers || []).length;
  const requiredProgress = respondentRequiredProgress(questions);
  const sections = respondentSections(questions);
  const currentSection = sections.find((section) => section.answered < section.total)?.name || sections[sections.length - 1]?.name || "Assessment";
  const saveStatusClass = respondentSaveStatus.toLowerCase().includes("unable") || respondentSaveStatus.toLowerCase().includes("fix") ? "error" : respondentSaveStatus.toLowerCase().includes("saving") || respondentSaveStatus.toLowerCase().includes("submitting") ? "saving" : "saved";
  root.innerHTML = `
    <section class="respondent-hero respondent-header">
      <div class="respondent-title-block">
        <p class="eyebrow">Secure Assessment</p>
        <h1>${escapeHtml(assessment.company_name || "Company Assessment")} — ${escapeHtml(participant.stakeholder_role_name || "Participant")}</h1>
        <p>${escapeHtml(assessment.name || "Business Assessment")}${participant.full_name ? ` · ${escapeHtml(participant.full_name)}` : ""}</p>
        <div class="respondent-save-pill ${saveStatusClass}">
          <span>${escapeHtml(respondentSaveStatus)}</span>
          ${respondentLastSavedAt ? `<small>Last saved ${escapeHtml(respondentLastSavedAt)}</small>` : ""}
        </div>
      </div>
      <div class="respondent-progress-card">
        <span>Progress</span>
        <strong>${progress.completion_percent || 0}%</strong>
        <div class="respondent-progress-track"><i style="width:${Math.min(100, Number(progress.completion_percent || 0))}%"></i></div>
        <small>${requiredProgress.answered}/${requiredProgress.total} required answered · ${progress.answered_count || 0}/${progress.total_questions || questions.length} total</small>
      </div>
    </section>
    <section class="respondent-section-nav">
      <div>
        <span>Current section</span>
        <strong>${escapeHtml(currentSection)}</strong>
      </div>
      <div class="respondent-section-steps">
        ${sections.map((section) => `<span class="${section.answered >= section.total ? "complete" : section.name === currentSection ? "active" : ""}">${escapeHtml(section.name)} <small>${section.answered}/${section.total}</small></span>`).join("")}
      </div>
    </section>
    <section class="respondent-card">
      <div class="respondent-welcome">
        <div>
          <h2>${completed ? "Assessment Completed" : `Welcome, ${escapeHtml(participant.full_name || "Participant")}`}</h2>
          <p>${completed ? "Thank you. Your responses will be included in the business intelligence review." : "Answer from your role's point of view. Your progress is saved automatically, and required questions are checked before submission."}</p>
        </div>
        ${completed ? `<span class="status-pill completed">Completed</span>` : `<span class="status-pill ${statusClass(participant.status || "invited")}">${participantStatusLabel(participant.status || "invited")}</span>`}
      </div>
      ${completed ? `<article class="respondent-completion-card"><strong>Assessment completed. Thank you.</strong><p>Role completed: ${escapeHtml(participant.stakeholder_role_name || "Participant")}</p><p>Submitted: ${escapeHtml(new Date(session.completed_at || respondentAssessmentState.token?.completed_at || Date.now()).toLocaleString())}</p></article>` : ""}
      ${questions.length ? `
        <form id="respondent-assessment-form" class="${completed ? "is-completed" : ""}">
          ${issueCount ? `
            <div class="respondent-validation-banner" role="alert">
              <strong>Please complete the highlighted required questions before submitting.</strong>
              <p>${issueCount} issue${issueCount === 1 ? "" : "s"} need attention. Valid saved answers are kept.</p>
            </div>
          ` : ""}
          <div class="respondent-question-list">
            ${questions.map((question, index) => {
              const issue = respondentIssueForQuestion(question.question_id);
              return `
              <article class="respondent-question ${issue ? "has-validation-error" : ""}" data-question-card="${escapeHtml(question.question_id)}">
                <div class="respondent-question-head">
                  <div><span>${String(index + 1).padStart(2, "0")}</span><small>${escapeHtml(question.section || "")}</small></div>
                  <div class="respondent-question-badges">${question.required ? '<small class="required">Required</small>' : '<small>Optional</small>'}${renderRespondentSavedIndicator(question)}</div>
                </div>
                <label for="respondent-${escapeHtml(question.question_id)}">${escapeHtml(question.question_text || "")}</label>
                ${question.ai_analysis_purpose ? `<p class="respondent-question-helper">${escapeHtml(question.ai_analysis_purpose)}</p>` : ""}
                ${renderRespondentField(question)}
                ${issue ? `<p class="respondent-field-error">${escapeHtml(issue)}</p>` : ""}
              </article>
            `;
            }).join("")}
          </div>
          <div class="respondent-actions respondent-submit-card">
            <div>
              <strong>${requiredProgress.missing ? `${requiredProgress.missing} required question${requiredProgress.missing === 1 ? "" : "s"} remaining` : "Ready to submit"}</strong>
              <span>${requiredProgress.answered}/${requiredProgress.total} required answered. You can continue later with the same link.</span>
            </div>
            <div class="respondent-submit-actions">
              <button class="ghost-button" id="respondent-save" type="button" ${completed ? "disabled" : ""}>Save</button>
              <button class="ghost-button" id="respondent-continue-later" type="button">Continue Later</button>
              <button class="primary-button" id="respondent-submit" type="submit" ${completed ? "disabled" : ""}>Submit Assessment</button>
            </div>
          </div>
          <p class="respondent-save-status ${saveStatusClass}" id="respondent-save-status">${escapeHtml(respondentSaveStatus)}</p>
        </form>
      ` : renderScreenState("respondent", "empty")}
    </section>
  `;
}
// EXTRACTED → participant.js — verify then remove

async function loadRespondentAssessment() {
  renderRespondentAssessment();
  try {
    respondentAssessmentState = await apiRequest(`/api/respond/${encodeURIComponent(activeRespondToken)}`);
    respondentValidationIssues = { missing_required_questions: [], invalid_answers: [] };
  } catch (error) {
    respondentAssessmentState = { error: error.message };
  }
  renderRespondentAssessment();
}
// EXTRACTED → participant.js — verify then remove

async function saveRespondentProgress({ complete = false } = {}) {
  if (!activeRespondToken || respondentAssessmentState?.session?.status === "completed") return;
  const status = document.querySelector("#respondent-save-status");
  respondentSaveStatus = complete ? "Submitting..." : "Saving...";
  if (status) status.textContent = respondentSaveStatus;
  const endpoint = complete
    ? `/api/respond/${encodeURIComponent(activeRespondToken)}/submit`
    : `/api/respond/${encodeURIComponent(activeRespondToken)}/responses`;
  try {
    respondentAssessmentState = await apiRequest(endpoint, {
      method: complete ? "POST" : "PATCH",
      body: JSON.stringify({ answers: collectRespondentAnswers() })
    });
    respondentValidationIssues = { missing_required_questions: [], invalid_answers: [] };
    respondentSaveStatus = complete ? "Submitted." : "Saved.";
    respondentLastSavedAt = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    renderRespondentAssessment();
    const refreshedStatus = document.querySelector("#respondent-save-status");
    if (refreshedStatus) refreshedStatus.textContent = respondentSaveStatus;
  } catch (error) {
    if (error.error === "validation_failed") {
      respondentValidationIssues = {
        missing_required_questions: error.missing_required_questions || [],
        invalid_answers: error.invalid_answers || []
      };
      respondentSaveStatus = error.message || "Please fix the highlighted answers.";
      renderRespondentAssessment();
      const firstIssue = document.querySelector(".respondent-question.has-validation-error");
      firstIssue?.scrollIntoView({ behavior: "smooth", block: "center" });
      const refreshedStatus = document.querySelector("#respondent-save-status");
      if (refreshedStatus) refreshedStatus.textContent = respondentSaveStatus;
      return;
    }
    respondentSaveStatus = "Unable to save. Please check your connection and try again.";
    if (status) status.textContent = respondentSaveStatus;
  }
}
// EXTRACTED → participant.js — verify then remove

function resolveRoleForEmail(email) {
  const normalized = normalizeEmail(email);
  if (!normalized) {
    return "participant";
  }
  if (platformUsers[normalized]) {
    return normalizeAppRole(platformUsers[normalized].role);
  }
  if (normalized === "fatih@deriveglobal.com" || normalized === "fatih@krb-assessment") {
    return "platform_owner";
  }
  return "participant";
}

function normalizeAppRole(role = "") {
  const value = String(role || "").trim().toLowerCase();
  if (["platform_owner", "platform_admin", "creator"].includes(value)) return "platform_owner";
  if (["consultant", "auditor"].includes(value)) return "consultant";
  if (["company_owner", "owner", "viewer"].includes(value)) return "company_owner";
  if (["assessment_manager", "manager"].includes(value)) return "assessment_manager";
  return value === "participant" ? "participant" : "participant";
}

function roleDisplayName(role = "") {
  const labels = {
    platform_owner: "Platform Owner",
    consultant: "Consultant",
    company_owner: "Company Owner",
    assessment_manager: "Assessment Manager",
    participant: "Participant"
  };
  return labels[normalizeAppRole(role)] || "Participant";
}

function commandCenterTitleForRole(role = currentRole) {
  const labels = {
    platform_owner: "Platform Command Center",
    consultant: "Consultant Command Center",
    company_owner: "Executive Command Center",
    assessment_manager: "Assessment Command Center",
    participant: "Participant Assessment"
  };
  return labels[normalizeAppRole(role)] || "Command Center";
}

function getOrganizationDisplayName() {
  return activeProject?.clientDisplayName
    || activeProject?.organizationName
    || activeProject?.name
    || companyProfile?.companyName
    || projectContextIntake?.organizationName
    || assessmentManagerCommandCenterState?.assigned_organization?.organization_name
    || assessmentManagerCommandCenterState?.assigned_organization?.name
    || "";
}

function getAssessmentDisplayName() {
  return assessmentEngineState?.assessment?.name
    || activeProject?.assessmentName
    || activeProject?.name
    || assessmentManagerCommandCenterState?.active_assessment?.name
    || "";
}

function getFrameworkDisplayName() {
  return assessmentEngineState?.assessment?.framework_name
    || assessmentEngineState?.assessment?.frameworkName
    || assessmentManagerCommandCenterState?.active_assessment?.framework_name
    || assessmentManagerCommandCenterState?.active_assessment?.frameworkName
    || activeProject?.frameworkName
    || activeProject?.methodologyName
    || activeProject?.framework
    || DEFAULT_FRAMEWORK_NAME;
}

function hasShellWorkspaceContext() {
  return Boolean(
    hasActiveWorkspace()
      || getOrganizationDisplayName()
      || getAssessmentDisplayName()
      || assessmentManagerCommandCenterState?.active_assessment
  );
}

const platformWorkspaceViews = new Set(["platform-command", "projects", "question-bank", "methodology", "users", "operations-center"]);
const frameworkWorkspaceViews = new Set(["question-bank", "methodology"]);

function isPlatformWorkspaceView(viewId = activeViewId) {
  return platformWorkspaceViews.has(viewId);
}

function isFrameworkWorkspaceView(viewId = activeViewId) {
  return frameworkWorkspaceViews.has(viewId);
}

function updateWorkspaceContext(viewId = "") {
  const strip = document.querySelector("#workspace-context-strip");
  if (!strip) return;
  const isRespondentView = normalizeAppRole(currentRole) === "participant";
  const role = roleDisplayName(currentRole);
  if (!isRespondentView && isPlatformWorkspaceView(viewId)) {
    const entries = isFrameworkWorkspaceView(viewId)
      ? [["Workspace", "Platform"], ["Section", "Frameworks"], ["Framework", DEFAULT_FRAMEWORK_NAME], ["Version", DEFAULT_FRAMEWORK_VERSION], ["Industry", DEFAULT_FRAMEWORK_INDUSTRY], ["Role", role]]
      : [["Workspace", "Platform"], ["Section", titles[viewId] || "Platform"], ["Role", role]];
    strip.innerHTML = entries
      .map(([label, value]) => `<span><strong>${escapeHtml(label)}:</strong> ${escapeHtml(value)}</span>`)
      .join("");
    strip.classList.add("is-global");
    return;
  }
  const hasShellContext = hasShellWorkspaceContext();
  const organization = hasShellContext ? getOrganizationDisplayName() || "Selected Organization" : "No organization selected";
  const assessment = hasShellContext ? getAssessmentDisplayName() || "No assessment selected" : "No assessment selected";
  const framework = hasShellContext ? getFrameworkDisplayName() : "No framework selected";
  const entries = isRespondentView
    ? [["Role", role]]
    : [["Organization", organization], ["Assessment", assessment], ["Framework", framework], ["Role", role]];
  strip.innerHTML = entries
    .map(([label, value]) => `<span><strong>${escapeHtml(label)}:</strong> ${escapeHtml(value)}</span>`)
    .join("");
  strip.classList.toggle("is-global", viewId === "projects" || !hasShellContext);
}

function workspaceLayerForView(viewId = activeViewId) {
  const role = normalizeAppRole(currentRole);
  if (role === "participant" || activeSurveyToken) return "respondent";
  if (isPlatformWorkspaceView(viewId)) return "platform";
  if (!hasShellWorkspaceContext()) return "platform";
  if (role === "company_owner") return "organization";
  if (["context", "projects", "roadmap"].includes(viewId)) return "organization";
  return "assessment";
}

function workspaceStageLabel() {
  const status = assessmentEngineState?.assessment?.status || activeProject?.status || "active";
  const findingCount = Number(assessmentEngineState?.findings?.length || 0);
  const recommendationCount = Number(assessmentEngineState?.recommendations?.length || 0);
  if (findingCount && recommendationCount) return "Executive Output";
  if (findingCount) return "Review";
  if (assessmentEngineState?.assessmentParticipants?.length) return "Collection";
  return status === "active" ? "Setup" : status;
}

function activeAssessmentStageLabel() {
  return ({
    setup: "Setup",
    collection: "Collection",
    review: "Review",
    recommendations: "Recommendations",
    executive: "Executive Output",
    operations: "Operations"
  })[activeAssessmentWorkspaceTab] || workspaceStageLabel();
}

function workspaceTabButton(tab, layer) {
  const role = normalizeAppRole(currentRole);
  if (tab.roles && !tab.roles.includes(role)) return "";
  const disabled = tab.requiresWorkspace && !hasShellWorkspaceContext();
  const active = tab.assessmentTab
    ? tab.view === activeViewId && activeAssessmentWorkspaceTab === tab.assessmentTab
    : tab.managerSection
    ? tab.view === activeViewId && activeManagerSection === tab.managerSection
    : tab.views ? tab.views.includes(activeViewId) : tab.view === activeViewId;
  const managerSection = tab.managerSection ? ` data-manager-section="${escapeHtml(tab.managerSection)}"` : "";
  const assessmentTab = tab.assessmentTab ? ` data-assessment-tab="${escapeHtml(tab.assessmentTab)}"` : "";
  return `
    <button class="workspace-tab ${active ? "active" : ""}" data-view="${escapeHtml(tab.view)}" data-roles="${escapeHtml(tab.roles.join(" "))}" data-workspace-layer="${escapeHtml(layer)}"${managerSection}${assessmentTab} type="button" ${disabled ? "disabled" : ""}>
      ${escapeHtml(tab.label)}
    </button>
  `;
}

function renderWorkspaceShell(viewId = activeViewId) {
  const shell = document.querySelector("#workspace-shell-panel");
  if (!shell) return;
  const role = normalizeAppRole(currentRole);
  if (role === "participant" || activeSurveyToken) {
    shell.classList.add("hidden");
    shell.innerHTML = "";
    return;
  }
  if (role === "company_owner") {
    // Owner shell manages its own navigation.
    // Do not render workspace tabs for this role.
    shell.classList.add("hidden");
    shell.innerHTML = "";
    return;
  }
  if (role === "consultant") {
    // Consultant shell manages its own stage navigation.
    // Do not render legacy workspace tabs for this role.
    shell.classList.add("hidden");
    shell.innerHTML = "";
    return;
  }
  if (role === "assessment_manager") {
    // Manager shell manages its own guided flow.
    // Do not render legacy workspace tabs for this role.
    shell.classList.add("hidden");
    shell.innerHTML = "";
    return;
  }
  if (role === "platform_owner") {
    // Platform shell manages platform navigation.
    // Existing platform views still render through shell callbacks.
    shell.classList.add("hidden");
    shell.innerHTML = "";
    return;
  }
  const layer = workspaceLayerForView(viewId);
  const hasShellContext = hasShellWorkspaceContext();
  const organization = getOrganizationDisplayName() || "No organization selected";
  const assessment = getAssessmentDisplayName() || "No assessment selected";
  const framework = getFrameworkDisplayName();
  const activeAssessments = hasShellContext && (assessmentEngineState?.assessment || getAssessmentDisplayName()) ? 1 : hasShellContext ? 0 : assessmentProjects.length;
  const status = activeProject?.status || assessmentEngineState?.assessment?.status || "active";
  const platformTabs = [
    { label: "Command Center", view: "platform-command", roles: ["platform_owner"] },
    { label: "Organizations", view: "projects", roles: ["platform_owner", "consultant"] },
    { label: "Frameworks", view: "question-bank", roles: ["platform_owner"], views: ["question-bank", "methodology"] },
    { label: "Operations", view: "operations-center", roles: ["platform_owner"] },
    { label: "Users & Access", view: "users", roles: ["platform_owner"] }
  ];
  const organizationTabs = role === "company_owner"
    ? [
        { label: "Home", view: "executive-preview", roles: ["company_owner"], requiresWorkspace: true },
        { label: "Executive Report", view: "executive-report", roles: ["company_owner"], requiresWorkspace: true },
        { label: "Roadmap & Progress", view: "roadmap", roles: ["company_owner"], requiresWorkspace: true }
      ]
    : [
        { label: "Home", view: "executive-preview", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Organization Profile", view: "context", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Assessments", view: "dashboard", roles: ["platform_owner", "consultant", "assessment_manager"], requiresWorkspace: true },
        { label: "Reports", view: "executive-report", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Progress", view: "roadmap", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Users", view: "users", roles: ["platform_owner"], requiresWorkspace: true }
      ];
  const assessmentTabs = role === "assessment_manager"
    ? [
        { label: "Command Center", view: "dashboard", roles: ["assessment_manager"], managerSection: "manager-overview", requiresWorkspace: true },
        { label: "Collection", view: "dashboard", roles: ["assessment_manager"], managerSection: "manager-participants", requiresWorkspace: true },
        { label: "Invitations & Reminders", view: "dashboard", roles: ["assessment_manager"], managerSection: "manager-communications", requiresWorkspace: true },
        { label: "Coverage", view: "dashboard", roles: ["assessment_manager"], managerSection: "manager-coverage", requiresWorkspace: true },
        { label: "Progress", view: "dashboard", roles: ["assessment_manager"], managerSection: "manager-progress", requiresWorkspace: true }
      ]
    : [
        { label: "Setup", view: "dashboard", assessmentTab: "setup", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Collection", view: "dashboard", assessmentTab: "collection", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Review", view: "dashboard", assessmentTab: "review", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Recommendations", view: "dashboard", assessmentTab: "recommendations", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Executive Output", view: "dashboard", assessmentTab: "executive", roles: ["platform_owner", "consultant"], requiresWorkspace: true },
        { label: "Operations", view: "dashboard", assessmentTab: "operations", roles: ["platform_owner"], requiresWorkspace: true }
      ];
  const tabs = layer === "platform" ? platformTabs : layer === "organization" ? organizationTabs : assessmentTabs;
  const layerButtons = [
    { layer: "platform", label: "Platform", view: role === "platform_owner" ? "platform-command" : "projects", roles: ["platform_owner", "consultant"], enabled: ["platform_owner", "consultant"].includes(role) },
    { layer: "organization", label: "Organization", view: role === "assessment_manager" ? "dashboard" : "executive-preview", roles: ["platform_owner", "consultant", "company_owner", "assessment_manager"], enabled: hasShellContext && ["platform_owner", "consultant", "company_owner", "assessment_manager"].includes(role) },
    { layer: "assessment", label: "Assessment", view: "dashboard", roles: ["platform_owner", "consultant", "assessment_manager"], enabled: hasShellContext && ["platform_owner", "consultant", "assessment_manager"].includes(role) }
  ];
  const layerTitle = layer === "platform"
    ? "Platform Workspace"
    : layer === "organization"
      ? "Organization Workspace"
      : "Assessment Workspace";
  const platformHeading = isFrameworkWorkspaceView(viewId) ? "Frameworks" : "Derive Platform";
  const layerSubtitle = layer === "platform"
    ? isFrameworkWorkspaceView(viewId)
      ? "Manage reusable framework definitions, question banks, blueprint rules, KPI expectations, and report templates."
      : "Operate the SaaS portfolio across organizations, frameworks, users, and health."
    : layer === "organization"
      ? "Understand the tenant, active assessments, reports, progress, and access."
      : "Run setup, collection, review, recommendations, executive output, and operations.";
  const headerMeta = layer === "platform"
    ? isFrameworkWorkspaceView(viewId)
      ? [["Framework", DEFAULT_FRAMEWORK_NAME], ["Version", DEFAULT_FRAMEWORK_VERSION], ["Industry", DEFAULT_FRAMEWORK_INDUSTRY], ["Role", roleDisplayName(currentRole)]]
      : [["Organizations", assessmentProjects.length], ["Section", titles[viewId] || "Platform"], ["Role", roleDisplayName(currentRole)]]
    : layer === "organization"
      ? [["Organization", organization], ["Framework", framework], ["Active Assessments", activeAssessments], ["Status", status]]
    : [["Assessment", assessment], ["Organization", organization], ["Framework", framework], ["Stage", activeAssessmentStageLabel()]];
  shell.classList.remove("hidden");
  shell.innerHTML = `
    <div class="workspace-shell-levels" aria-label="Workspace levels">
      ${layerButtons.filter((item) => item.roles.includes(role)).map((item) => `
        <button class="workspace-level ${layer === item.layer ? "active" : ""}" data-view="${escapeHtml(item.view)}" data-roles="${escapeHtml(item.roles.join(" "))}" type="button" ${item.enabled ? "" : "disabled"}>
          <span>${escapeHtml(item.label)}</span>
        </button>
      `).join("")}
    </div>
    <div class="workspace-shell-card">
      <div class="workspace-shell-heading">
        <div>
          <span class="eyebrow">${escapeHtml(layerTitle)}</span>
          <h2>${escapeHtml(layer === "platform" ? platformHeading : layer === "organization" ? organization : assessment)}</h2>
          <p>${escapeHtml(layerSubtitle)}</p>
        </div>
        <div class="workspace-shell-meta">
          ${headerMeta.map(([label, value]) => `<span><strong>${escapeHtml(label)}</strong>${escapeHtml(String(value || "-"))}</span>`).join("")}
        </div>
      </div>
      <div class="workspace-shell-tabs" aria-label="${escapeHtml(layerTitle)} navigation">
        ${tabs.map((tab) => workspaceTabButton(tab, layer)).join("")}
      </div>
    </div>
  `;
}

function getDefaultViewForRole(role) {
  const userRole = normalizeAppRole(role);
  if (userRole === "participant") {
    return "surveys";
  }
  if (normalizeAppRole(role) === "company_owner") {
    return "owner-surface";
  }
  if (normalizeAppRole(role) === "consultant") {
    return "consultant-surface";
  }
  if (normalizeAppRole(role) === "assessment_manager") {
    return "manager-surface";
  }
  if (normalizeAppRole(role) === "platform_owner") {
    return "platform-surface";
  }
  if (["platform_owner", "consultant"].includes(userRole)) {
    return userRole === "platform_owner" ? "platform-command" : "projects";
  }
  return "permission-denied";
}

function setActiveView(viewId) {
  if (viewId === "owner-surface") {
    // Owner surface is managed by shells/owner.js.
    // Do not apply standard show/hide logic.
    return;
  }
  if (viewId === "consultant-surface") {
    // Consultant surface is managed by shells/consultant.js.
    // Do not apply standard show/hide logic.
    return;
  }
  if (viewId === "manager-surface") {
    // Manager surface is managed by shells/manager.js.
    // Do not apply standard show/hide logic.
    return;
  }
  if (viewId === "platform-surface") {
    // Platform surface is managed by shells/platform.js.
    // Do not apply standard show/hide logic.
    return;
  }
  activeViewId = viewId;
  if (!viewAllowedForRole(viewId)) {
    const deniedView = ensurePermissionDeniedView();
    document.querySelectorAll(".nav-item, .view").forEach((item) => item.classList.remove("active"));
    deniedView.classList.add("active");deniedView.style.setProperty("display","none","important");setTimeout(function(){if(deniedView.classList.contains("active"))deniedView.style.removeProperty("display");},1500);
    deniedView.innerHTML = `
      <section class="panel">
        <div class="panel-header">
          <h2>Permission Denied</h2>
          <span>Access control</span>
        </div>
        ${renderScreenState(viewId, "permission", {
          ...(screenStateCopy[viewId]?.permission || {}),
          title: screenStateCopy[viewId]?.permission?.title || "You do not have access to this screen",
          message: screenStateCopy[viewId]?.permission?.message || "This area is restricted for your current user type.",
          actionLabel: "Go To My Start Page",
          actionView: getDefaultViewForRole(currentRole)
        })}
      </section>
    `;
    document.querySelector("#view-title").textContent = "Permission Denied";
    const eyebrow = document.querySelector("#workspace-eyebrow");
    if (eyebrow) eyebrow.textContent = "Assessment Platform";
    updateWorkspaceContext(viewId);
    renderWorkspaceShell(viewId);
    updateGlobalActionVisibility(viewId);
    return;
  }
  document.querySelectorAll(".nav-item, .view").forEach((item) => item.classList.remove("active"));
  const button = [...document.querySelectorAll(`[data-view="${viewId}"]`)].find((item) => {
    if (item.classList.contains("hidden")) return false;
    if (!item.dataset.roles) return true;
    return item.dataset.roles.split(" ").includes(normalizeAppRole(currentRole));
  }) || document.querySelector(`[data-view="${viewId}"]`);
  const view = document.querySelector(`#${viewId}`);
  if (button) {
    button.classList.add("active");
  }
  if (view) {
    view.classList.add("active");
  }
  document.querySelector("#view-title").textContent = viewId === getDefaultViewForRole(currentRole) ? commandCenterTitleForRole(currentRole) : (titles[viewId] || "Assessment Platform");
  const eyebrow = document.querySelector("#workspace-eyebrow");
  if (eyebrow) {
    eyebrow.textContent = isPlatformWorkspaceView(viewId)
      ? "Platform Workspace"
      : viewId === "projects" || !hasActiveWorkspace()
        ? "Assessment Platform"
        : `${getOrganizationDisplayName() || "Selected Organization"} Workspace`;
  }
  updateWorkspaceContext(viewId);
  renderWorkspaceShell(viewId);
  updateGlobalActionVisibility(viewId);
}

function updateGlobalActionVisibility(viewId = activeViewId) {
  const exportButton = document.querySelector("#export-report");
  if (!exportButton) return;
  const role = normalizeAppRole(currentRole);
  exportButton.classList.toggle("hidden", viewId !== "executive-report" || role === "participant" || role === "assessment_manager");
}

function applyShellChromeState(shellManagedRole) {
  const sidebar = document.querySelector(".sidebar");
  const topbar = document.querySelector(".topbar");
  const workspaceShell = document.querySelector("#workspace-shell-panel");
  const main = document.querySelector(".main");
  const appShell = document.querySelector(".app-shell");
  sidebar?.classList.toggle("hidden", shellManagedRole);
  topbar?.classList.toggle("hidden", shellManagedRole);
  workspaceShell?.classList.toggle("hidden", shellManagedRole);
  if (appShell) {
    appShell.style.display = shellManagedRole ? "block" : "none";  // APPSHELL_HIDE_FIX: non-shell roles hide legacy shell (was "" = visible grid, leaked over login/dashboard on mobile)
    appShell.style.minHeight = shellManagedRole ? "100vh" : "";
    appShell.style.background = shellManagedRole ? "var(--color-bg)" : "";
  }
  if (main) {
    main.style.width = shellManagedRole ? "100%" : "";
    main.style.maxWidth = shellManagedRole ? "none" : "";
    main.style.margin = shellManagedRole ? "0" : "";
    main.style.padding = shellManagedRole ? "0" : "";
    main.style.minHeight = shellManagedRole ? "100vh" : "";
    main.style.background = shellManagedRole ? "var(--color-bg)" : "";
  }
}

function applyRole(role) {
  currentRole = normalizeAppRole(role);
  if (isPortfolioRole(role) && !activeSurveyToken && !activeContextToken) {
    clearActiveWorkspace();
  }
  document.body.dataset.role = currentRole;
  const ownerSurface = document.getElementById("owner-surface");
  const consultantSurface = document.getElementById("consultant-surface");
  const managerSurface = document.getElementById("manager-surface");
  const platformSurface = document.getElementById("platform-surface");
  if (ownerSurface && currentRole !== "company_owner") ownerSurface.style.display = "none";
  if (consultantSurface && currentRole !== "consultant") consultantSurface.style.display = "none";
  if (managerSurface && currentRole !== "assessment_manager") managerSurface.style.display = "none";
  if (platformSurface && currentRole !== "platform_owner") platformSurface.style.display = "none";
  const shellManagedRole = ["company_owner", "consultant", "assessment_manager", "platform_owner"].includes(currentRole);
  applyShellChromeState(shellManagedRole);
  // platform_owner has its own shell (shells/platform.js) rendered below.
  // initPlatformSession() synchronously hides .main and .app-shell as a pre-hide guard
  // for the BI/saha module surfaces — but platform-surface lives INSIDE .main, so
  // calling initPlatformSession() here would hide the parent and leave a dark screen.
  if (currentRole !== "platform_owner") {
    initPlatformSession();
  }

  document.querySelectorAll("[data-roles]").forEach((item) => {
    const roles = item.dataset.roles.split(" ");
    item.classList.toggle("hidden", !roles.includes(currentRole));
  });

  document.querySelectorAll(".creator-only").forEach((item) => item.classList.toggle("hidden", currentRole !== "platform_owner"));
  document.querySelectorAll(".operator-only").forEach((item) => item.classList.toggle("hidden", !["platform_owner", "consultant", "assessment_manager"].includes(currentRole)));
  document.querySelectorAll(".owner-only").forEach((item) => item.classList.toggle("hidden", currentRole !== "company_owner"));
  document.querySelectorAll(".participant-only").forEach((item) => item.classList.toggle("hidden", currentRole !== "participant"));

  updateGlobalActionVisibility(activeViewId);

  const defaultView = activeContextToken ? "context" : activeSurveyToken ? "surveys" : getDefaultViewForRole(role);
  if (normalizeAppRole(role) === "platform_owner") {
    const surface = document.getElementById("platform-surface");
    document.querySelectorAll(".nav-item, .view").forEach((item) => item.classList.remove("active"));
    document.querySelector("#auth-screen")?.classList.add("hidden");
    if (surface) {
      surface.style.display = "block";
      surface.style.width = "100vw";
      surface.style.minHeight = "100vh";
    }
    import("./shells/platform.js")
      .then(({ initPlatformSurface }) => {
        const container = document.getElementById("platform-surface");
        if (container) {
          initPlatformSurface(
            container,
            buildPlatformCallbacks()
          );
        }
      }).catch((err) => {
        console.error(
          "Platform shell failed to load:",
          err
        );
      });
    return;
  }
  if (normalizeAppRole(role) === "company_owner") {
    // If initPlatformSession() is in flight, it will handle routing — skip old owner shell
    if (window.__platformSessionPending) return;
    const ownerContainer = document.getElementById("owner-surface");
    document.querySelectorAll(".nav-item, .view").forEach((item) => item.classList.remove("active"));
    document.querySelector("#auth-screen")?.classList.add("hidden");
    if (ownerContainer) {
      ownerContainer.style.display = "block";
      ownerContainer.style.width = "100vw";
      ownerContainer.style.minHeight = "100vh";
    }
    import("./shells/owner.js").then(({ initOwnerSurface }) => {
      const container = document.getElementById("owner-surface");
      if (container) {
        initOwnerSurface(container);
      }
    }).catch((err) => {
      console.error("Owner shell failed to load:", err);
    });
    return;
  }
  if (normalizeAppRole(role) === "consultant") {
    const surface = document.getElementById("consultant-surface");
    document.querySelectorAll(".nav-item, .view").forEach((item) => item.classList.remove("active"));
    document.querySelector("#auth-screen")?.classList.add("hidden");
    if (!activeProject && assessmentProjects.length) {
      saveActiveProject(assessmentProjects[0]);
    }
    if (surface) {
      surface.style.display = "block";
      surface.style.width = "100vw";
      surface.style.minHeight = "100vh";
    }
    import("./shells/consultant.js")
      .then(({ initConsultantSurface }) => {
        const container = document.getElementById("consultant-surface");
        if (container) {
          initConsultantSurface(
            container,
            buildConsultantCallbacks()
          );
        }
        if (activeProject?.id) {
          refreshAssessmentEngine();
        }
      }).catch((err) => {
        console.error(
          "Consultant shell failed to load:",
          err
        );
      });
    return;
  }
  if (normalizeAppRole(role) === "assessment_manager") {
    const surface = document.getElementById("manager-surface");
    document.querySelectorAll(".nav-item, .view").forEach((item) => item.classList.remove("active"));
    document.querySelector("#auth-screen")?.classList.add("hidden");
    if (!activeProject && assessmentProjects.length) {
      saveActiveProject(assessmentProjects[0]);
    }
    if (surface) {
      surface.style.display = "block";
      surface.style.width = "100vw";
      surface.style.minHeight = "100vh";
    }
    import("./shells/manager.js")
      .then(({ initManagerSurface }) => {
        const container = document.getElementById("manager-surface");
        if (container) {
          initManagerSurface(
            container,
            buildManagerCallbacks()
          );
        }
        if (activeProject?.id) {
          refreshAssessmentEngine();
        }
      }).catch((err) => {
        console.error(
          "Manager shell failed to load:",
          err
        );
      });
    return;
  }
  if (window.__platformSessionPending) return;
  setActiveView(defaultView);
}

function badgeClass(value) {
  return value.toLowerCase().replace(/\s+/g, "-");
}

function renderMetrics() {
  const container = document.querySelector("#metrics");
  if (!container) return;
  if (!hasActiveWorkspace()) {
    const metrics = [
      ["Organizations", assessmentProjects.length],
      ["Active Workspace", "None"],
      ["Generated Questions", questionBankRoles.reduce((sum, role) => sum + role.questions.length, 0)],
      ["Framework Coverage", `${questionBankRoles.filter((role) => role.questions.length).length}/${questionBankRoles.length}`]
    ];
    container.innerHTML = metrics
      .map((metric) => `<article class="metric"><span>${metric[0]}</span><strong>${metric[1]}</strong></article>`)
      .join("");
    return;
  }
  const generatedQuestions = questionBankRoles.reduce((sum, role) => sum + role.questions.length, 0);
  const generatedRoles = questionBankRoles.filter((role) => role.questions.length).length;
  const engineFindings = assessmentEngineState?.findings || [];
  const engineRecommendations = assessmentEngineState?.recommendations || [];
  const approvedFindingCount = engineFindings.filter((finding) => finding.status === "Approved").length;
  const approvedRecommendationCount = engineRecommendations.filter((recommendation) => isRecommendationVisibleStatus(recommendation.status)).length;
  const metrics = [
    ["Approved Findings", approvedFindingCount],
    ["Approved Recommendations", approvedRecommendationCount],
    ["Stored Responses", responses.length || 0],
    ["Framework Coverage", `${generatedRoles}/${questionBankRoles.length}`],
    ["Question Items", generatedQuestions]
  ];

  container.innerHTML = metrics
    .map((metric) => `<article class="metric"><span>${metric[0]}</span><strong>${metric[1]}</strong></article>`)
    .join("");
}

function consultantLifecycleClass(status = "") {
  const normalized = String(status || "").toLowerCase().replace(/\s+/g, "-");
  if (normalized === "executive-ready") return "approved";
  if (normalized === "review") return "in-progress";
  if (normalized === "collecting") return "warning";
  return "draft";
}

function consultantSeverityClass(severity = "") {
  if (severity === "high") return "danger";
  if (severity === "medium") return "warning";
  return "success";
}

function consultantActionLabel(item = {}) {
  if (!item) return "Open";
  if (item.action_view === "findings") return "Review Findings";
  if (item.action_view === "opportunities") return "Review Recommendations";
  if (item.action_view === "executive-report") return "View Report";
  if (item.type === "analysis_ready") return "Run Analysis";
  if (item.type === "missing_participants") return "Open Participants";
  if (item.type === "overdue_participants") return "Open Collection";
  return "Open Assessment";
}

function renderConsultantTaskButton(item = {}, className = "ghost-button") {
  return `<button class="${className}" data-consultant-open-project="${escapeHtml(item.project_id || "")}" data-consultant-view="${escapeHtml(item.action_view || "dashboard")}" type="button">${escapeHtml(consultantActionLabel(item))}</button>`;
}

function platformSeverityClass(severity = "") {
  if (severity === "critical") return "danger";
  if (severity === "high") return "danger";
  if (severity === "medium") return "warning";
  return "success";
}

function platformStageClass(stage = "") {
  const normalized = String(stage || "").toLowerCase().replace(/\s+/g, "-");
  if (normalized === "executive-ready" || normalized === "completed") return "approved";
  if (normalized === "review" || normalized === "recommendations") return "in-progress";
  if (normalized === "collecting") return "warning";
  return "draft";
}

function platformTaskButton(item = {}, className = "ghost-button") {
  return `<button class="${className}" data-platform-open-project="${escapeHtml(item.project_id || "")}" data-platform-view="${escapeHtml(item.action_view || "dashboard")}" type="button">${escapeHtml(item.action_label || "Open")}</button>`;
}

function renderPlatformMetric(label, value, note = "") {
  const hasValue = value !== null && value !== undefined && value !== "";
  return `
    <article>
      <span>${escapeHtml(label)}</span>
      <strong>${hasValue ? escapeHtml(String(value)) : "No data yet"}</strong>
      ${note ? `<small>${escapeHtml(note)}</small>` : ""}
    </article>
  `;
}

function renderPlatformCommandCenter() {
  const root = document.querySelector("#platform-command-center-root");
  if (!root) return;
  if (platformCommandCenterError) {
    root.innerHTML = renderScreenState("projects", "error", {
      title: "Platform Command Center could not load",
      message: platformCommandCenterError,
      actionLabel: "Refresh",
      actionView: "platform-command"
    });
    return;
  }
  const state = platformCommandCenterState;
  if (!state) {
    root.innerHTML = renderLoadingSkeleton("Loading Platform Command Center", 6);
    return;
  }
  const snapshots = state.classification_snapshots || {};
  const activeClassification = snapshots[platformClassificationFilter] ? platformClassificationFilter : "production";
  const snapshot = snapshots[activeClassification] || state.platform_snapshot || {};
  const allOrganizations = state.organization_portfolio_all || state.organization_portfolio_summary || [];
  const organizations = activeClassification === "all"
    ? allOrganizations
    : allOrganizations.filter((org) => (org.classification || "production") === activeClassification);
  const allAttention = state.needs_attention_all || state.needs_attention || [];
  const attention = activeClassification === "all"
    ? allAttention
    : allAttention.filter((item) => (item.classification || "production") === activeClassification);
  const pipeline = organizations.reduce((totals, org) => {
    if (org.stage === "Setup") totals.setup += 1;
    else if (org.stage === "Collecting") totals.collecting += 1;
    else if (org.stage === "Review") totals.review += 1;
    else if (org.stage === "Executive Ready") totals.executive_ready += 1;
    if (org.stage === "Executive Ready" && org.report_status === "Ready") totals.recommendations += 1;
    if (org.assessment_status === "completed") totals.completed += 1;
    if (Number(org.completion_percent || 0) < 100 && (Number(org.open_issues || 0) || attention.some((item) => item.project_id === org.project_id && ["critical", "high"].includes(item.severity)))) totals.at_risk += 1;
    return totals;
  }, { setup: 0, collecting: 0, review: 0, recommendations: 0, executive_ready: 0, completed: 0, at_risk: 0 });
  const consultants = state.consultant_workload || [];
  const allReports = state.reports_ready_all || state.reports_ready || [];
  const reports = activeClassification === "all"
    ? allReports
    : allReports.filter((report) => (report.classification || "production") === activeClassification);
  const ops = state.operations_health || {};
  const allIssues = state.open_issues_all || state.open_issues || [];
  const issues = activeClassification === "all"
    ? allIssues
    : allIssues.filter((issue) => (issue.classification || "production") === activeClassification);
  const activity = state.recent_activity || [];
  const next = attention[0] || (reports[0] ? {
    type: "report_ready",
    severity: "low",
    organization_name: reports[0].organization_name,
    assessment_name: reports[0].assessment_name,
    project_id: reports[0].project_id,
    label: "Executive report ready",
    explanation: "Review the report before delivery.",
    action_label: "Open Report",
    action_view: "executive-report"
  } : state.next_best_action);

  if (!Number(snapshot.total_organizations || 0)) {
    root.innerHTML = renderScreenState("projects", "empty", {
      title: "No organizations yet",
      message: "Create your first organization to start an assessment.",
      actionLabel: "Create Organization",
      actionView: "projects"
    });
    return;
  }

  root.innerHTML = `
    <section class="platform-command">
      <section class="panel platform-hero">
        <div>
          <span class="eyebrow">Platform Command Center</span>
          <h2>SaaS mission control across every organization and assessment.</h2>
          <p>Platform-wide status, tenant risks, delivery workload, report readiness, operations health, and the next best action are consolidated here.</p>
          <div class="owner-command-meta">
            <span>Generated: ${escapeHtml(formatOpsDate(state.generated_at))}</span>
            <span>Role: Platform Owner</span>
            <span>Scope: ${activeClassification === "all" ? "All classifications" : `${activeClassification} organizations`}</span>
          </div>
        </div>
        <div class="platform-next-action">
          <span class="eyebrow">Next Best Action</span>
          ${next ? `
            <span class="status-pill ${platformSeverityClass(next.severity)}">${escapeHtml(next.severity || "priority")}</span>
            <h3>${escapeHtml(next.label || "Open action")}</h3>
            <p>${escapeHtml(next.organization_name || "Platform")} · ${escapeHtml(next.explanation || "")}</p>
            ${platformTaskButton(next, "primary-button")}
          ` : `
            <h3>No urgent platform action</h3>
            <p>There are no blocked assessments, critical issues, failed communications, or report-review alerts right now.</p>
          `}
        </div>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div><h2>Platform Snapshot</h2><span>Cross-tenant operating signals</span></div>
          <div class="panel-actions">
            <div class="segmented-control platform-classification-toggle" aria-label="Filter platform metrics by classification">
              ${["production", "demo", "qa", "internal", "all"].map((classification) => `
                <button class="${activeClassification === classification ? "active" : ""}" data-platform-classification-filter="${classification}" type="button">${escapeHtml(classification === "qa" ? "QA" : classification.charAt(0).toUpperCase() + classification.slice(1))}</button>
              `).join("")}
            </div>
            <button class="ghost-button" id="refresh-platform-command-center" type="button">Refresh</button>
          </div>
        </div>
        <div class="platform-metric-grid">
          ${renderPlatformMetric("Production Organizations", snapshot.production_organizations)}
          ${renderPlatformMetric("Demo Organizations", snapshot.demo_organizations)}
          ${renderPlatformMetric("QA Organizations", snapshot.qa_organizations)}
          ${renderPlatformMetric("Internal Organizations", snapshot.internal_organizations)}
          ${renderPlatformMetric("Active Workspaces", snapshot.active_workspaces)}
          ${renderPlatformMetric("Active Assessments", snapshot.active_assessments)}
          ${renderPlatformMetric("Collecting Responses", snapshot.collecting_responses)}
          ${renderPlatformMetric("Analysis Ready", snapshot.analysis_ready)}
          ${renderPlatformMetric("Reports Ready", snapshot.reports_ready)}
          ${renderPlatformMetric("Completed Assessments", snapshot.completed_assessments)}
          ${renderPlatformMetric("Overdue Participants", snapshot.overdue_participants)}
          ${renderPlatformMetric("Failed Invitations", snapshot.failed_invitations)}
          ${renderPlatformMetric("Failed Reminders", snapshot.failed_reminders)}
          ${renderPlatformMetric("Participants Without Usable Link", snapshot.participants_without_usable_link)}
          ${renderPlatformMetric("Open Issues", snapshot.open_issues)}
          ${renderPlatformMetric("Generated Warnings", snapshot.generated_warnings)}
          ${renderPlatformMetric("Critical Issues", snapshot.critical_issues)}
          ${renderPlatformMetric("Estimated Value Identified", formatEstimatedValue(snapshot.estimated_value_identified || 0))}
          ${renderPlatformMetric("Actual Value Realized", formatEstimatedValue(snapshot.actual_value_realized || 0))}
        </div>
      </section>

      <section class="platform-grid">
        <article class="panel">
          <div class="panel-header">
            <div><h2>Needs Attention</h2><span>Prioritized cross-tenant action queue</span></div>
          </div>
          <div class="consultant-list">
            ${attention.length ? attention.slice(0, 10).map((item) => `
              <div class="consultant-list-item">
                <span class="status-pill ${platformSeverityClass(item.severity)}">${escapeHtml(item.severity || "priority")}</span>
                <div><strong>${escapeHtml(item.label)}</strong><small>${escapeHtml(item.organization_name || "Organization")} · ${escapeHtml(item.assessment_name || "Assessment")} · ${escapeHtml(item.explanation || "")}</small></div>
                ${platformTaskButton(item)}
              </div>
            `).join("") : `<p class="upload-note">No organizations currently need attention.</p>`}
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div><h2>Assessment Pipeline</h2><span>Delivery stages across the platform</span></div>
          </div>
          <div class="consultant-pipeline-grid">
            ${[
              ["Setup", pipeline.setup || 0],
              ["Collecting", pipeline.collecting || 0],
              ["Review", pipeline.review || 0],
              ["Recommendations", pipeline.recommendations || 0],
              ["Executive Ready", pipeline.executive_ready || 0],
              ["Completed", pipeline.completed || 0],
              ["At Risk", pipeline.at_risk || 0]
            ].map(([label, count]) => `<article><span>${label}</span><strong>${count}</strong></article>`).join("")}
          </div>
        </article>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div><h2>Organization Portfolio</h2><span>${activeClassification === "all" ? "All active workspaces" : `${activeClassification} active workspaces`} with stage, readiness, and ownership</span></div>
          <button class="ghost-button" data-view="projects" type="button">Open Organizations</button>
        </div>
        <div class="table-scroll">
          <table class="compact-table platform-table">
            <thead>
              <tr><th>Organization</th><th>Classification</th><th>Framework</th><th>Assessment</th><th>Stage</th><th>Completion</th><th>Confidence</th><th>Issues</th><th>Report</th><th>Last Activity</th><th>Consultant</th><th>Next Action</th></tr>
            </thead>
            <tbody>
              ${organizations.map((org) => `
                <tr>
                  <td><button class="link-button" data-platform-open-project="${escapeHtml(org.project_id)}" data-platform-view="dashboard" type="button">${escapeHtml(org.organization_name)}</button></td>
                  <td><span class="status-pill ${statusClass(org.classification || "production")}">${escapeHtml(org.classification || "production")}</span></td>
                  <td>${escapeHtml(org.framework_name || "Framework")}</td>
                  <td>${escapeHtml(org.assessment_name || "Assessment")}</td>
                  <td><span class="status-pill ${platformStageClass(org.stage)}">${escapeHtml(org.stage || "Setup")}</span></td>
                  <td>${Number(org.completion_percent || 0)}%</td>
                  <td>${Number(org.confidence_score || 0)}%</td>
                  <td>${Number(org.open_issues || 0)}</td>
                  <td>${escapeHtml(org.report_status || "Not Ready")}</td>
                  <td>${escapeHtml(formatOpsDate(org.last_activity))}</td>
                  <td>${escapeHtml(org.assigned_consultant || "Unassigned")}</td>
                  <td><button class="ghost-button" data-platform-open-project="${escapeHtml(org.project_id)}" data-platform-view="${org.report_ready ? "executive-report" : "dashboard"}" type="button">${escapeHtml(org.next_action || "Open")}</button></td>
                </tr>
              `).join("") || `<tr><td colspan="12">No active organizations found for this classification.</td></tr>`}
            </tbody>
          </table>
        </div>
      </section>

      <section class="platform-grid">
        <article class="panel">
          <div class="panel-header">
            <div><h2>Consultant Workload</h2><span>Delivery team capacity and queues</span></div>
            <button class="ghost-button" data-view="users" type="button">Open Users & Access</button>
          </div>
          <div class="consultant-list">
            ${consultants.length ? consultants.map((consultant) => `
              <div class="consultant-list-item">
                <span class="status-dot ${consultant.open_issues ? "warning" : "success"}"></span>
                <div>
                  <strong>${escapeHtml(consultant.consultant_name || consultant.email)}</strong>
                  <small>${consultant.assigned_organizations} orgs · ${consultant.active_assessments} active · ${consultant.findings_pending_review} findings pending · ${consultant.reports_ready} reports ready · ${consultant.overdue_collection_items} overdue · ${consultant.open_issues} issues</small>
                </div>
              </div>
            `).join("") : `
              ${renderScreenState("users", "empty", {
                compact: true,
                title: "No consultants assigned yet",
                message: "Create or assign consultants so platform delivery work has clear ownership.",
                actionLabel: "Open Users & Access",
                actionView: "users"
              })}
            `}
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div><h2>Reports Ready</h2><span>Executive reports ready for review or delivery</span></div>
          </div>
          <div class="consultant-list">
            ${reports.length ? reports.map((report) => `
              <div class="consultant-list-item">
                <span class="status-pill approved">ready</span>
                <div><strong>${escapeHtml(report.organization_name)}</strong><small>${escapeHtml(report.assessment_name || "Assessment")} · ${formatEstimatedValue(report.estimated_value || 0)} value · ${escapeHtml(formatOpsDate(report.last_updated))}</small></div>
                <button class="ghost-button" data-platform-open-project="${escapeHtml(report.project_id)}" data-platform-view="executive-report" type="button">Open Report</button>
              </div>
            `).join("") : `<p class="upload-note">No reports are ready for review yet.</p>`}
          </div>
        </article>
      </section>

      <section class="platform-grid">
        <article class="panel">
          <div class="panel-header">
            <div><h2>Operations Health</h2><span>Email, magic links, analysis, report, and backend signals</span></div>
            <button class="ghost-button" data-view="operations-center" type="button">Open Operations Center</button>
          </div>
          <div class="manager-metric-grid">
            ${[
              ["Email Provider", ops.email_provider_status || "unknown"],
              ["Failed Invitations", ops.failed_invitations || 0],
              ["Failed Reminders", ops.failed_reminders || 0],
              ["Participants Without Usable Link", ops.participants_without_usable_link || 0],
              ["Expired Tokens", ops.expired_tokens || 0],
              ["Sessions Without Tokens", ops.sessions_without_tokens || 0],
              ["Participants Without Sessions", ops.participants_without_sessions || 0],
              ["Completed Sessions Without Findings", ops.completed_sessions_without_findings || 0],
              ["Reports Missing Sections", ops.reports_missing_required_sections || 0],
              ["Generated Warnings", ops.generated_warnings || 0],
              ["Recent Backend Errors", ops.recent_backend_errors || 0]
            ].map(([label, value]) => `<article><span>${label}</span><strong>${escapeHtml(String(value))}</strong></article>`).join("")}
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div><h2>Open Issues</h2><span>Critical and high issues first</span></div>
            <button class="ghost-button" data-view="operations-center" type="button">Open Issues</button>
          </div>
          <div class="consultant-list">
            ${issues.length ? issues.slice(0, 8).map((issue) => `
              <div class="consultant-list-item">
                <span class="status-pill ${platformSeverityClass(issue.severity)}">${escapeHtml(issue.severity || "issue")}</span>
                <div><strong>${escapeHtml(issue.title || "Issue")}</strong><small>${escapeHtml(issue.organization_name || "")} ${issue.assessment_name ? `· ${escapeHtml(issue.assessment_name)}` : ""} · ${escapeHtml(issue.status || "open")}</small></div>
                <button class="ghost-button" data-view="operations-center" type="button">Open Issue</button>
              </div>
            `).join("") : `<p class="upload-note">No open issues. Platform health is clear.</p>`}
          </div>
        </article>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div><h2>Recent Activity</h2><span>Latest platform events</span></div>
        </div>
        <div class="platform-activity-list">
          ${activity.length ? activity.slice(0, 12).map((item) => `
            <div>
              <span class="status-dot success"></span>
              <strong>${escapeHtml(String(item.action || "activity").replace(/_/g, " "))}</strong>
              <small>${escapeHtml(item.entity_type || "platform")} · ${escapeHtml(formatOpsDate(item.happened_at))}${item.actor_email ? ` · ${escapeHtml(item.actor_email)}` : ""}</small>
            </div>
          `).join("") : `<p class="upload-note">No recent platform activity yet.</p>`}
        </div>
      </section>
    </section>
  `;
}

function renderProjects() {
  const list = document.querySelector("#project-list");
  if (!list) return;
  const projects = assessmentProjects;

  if (!projects.length) {
    list.innerHTML = renderScreenState("projects", "empty");
    return;
  }

  list.innerHTML = projects
    .map(
      (project) => `
        <article class="project-card ${hasActiveWorkspace() && activeProject?.id === project.id ? "active" : ""}">
          <div>
            <span class="eyebrow">${project.status || "active"}</span>
            <h3>${project.clientDisplayName || project.organizationName || project.name}</h3>
            <p>${project.industryContext || "Digital transformation assessment workspace."}</p>
          </div>
          <div class="project-meta">
            <span>${project.assignmentCount || 0} assignments</span>
            <span>${project.responseCount || 0} responses</span>
            <span>${(project.defaultLanguage || "en").toUpperCase()}</span>
          </div>
          <button class="primary-button" data-open-project="${project.id}" type="button">Open Workspace</button>
        </article>
      `
    )
    .join("");
}

function getContextLanguage() {
  return activeContextLanguage || projectContextIntake?.language || activeSurveyLanguage || activeProject?.defaultLanguage || "tr";
}

function getContextCopy(value) {
  const language = getContextLanguage();
  if (typeof value === "object") return value[language] || value.en || value.tr || "";
  return value || "";
}

function getContextOptionLabel(option) {
  if (typeof option === "object") {
    return getContextLanguage() === "tr" ? option.tr || option.label : option.label;
  }
  return getContextLanguage() === "tr" ? contextOptionTranslations[option] || option : option;
}

function getContextOptionValue(option) {
  return typeof option === "object" ? option.id : option;
}

function getContextOptionDescription(option) {
  if (typeof option !== "object") return "";
  if (getContextLanguage() === "tr") return option.trDescription || "";
  return option.description || "";
}

function renderContextCheckboxOption(option, selected, name) {
  const optionValue = getContextOptionValue(option);
  const description = getContextOptionDescription(option);
  return `
    <label class="checkbox-option ${description ? "with-description" : ""}" ${description ? `title="${escapeHtml(description)}"` : ""}>
      <input type="checkbox" name="${name}" value="${escapeHtml(optionValue)}" ${selected.includes(optionValue) ? "checked" : ""} />
      <span>
        <strong>${escapeHtml(getContextOptionLabel(option))}</strong>
      </span>
    </label>
  `;
}

function getSelectedIndustry(values) {
  return values.industry || "tire_industry";
}

function renderContextField(field, values) {
  const selectedIndustry = getSelectedIndustry(values);
  if (field.dependsOnIndustry && field.dependsOnIndustry !== selectedIndustry) {
    return "";
  }

  const value = values[field.id];
  const label = getContextCopy(field.label);
  const required = field.required ? "required" : "";
  const name = `context_${field.id}`;

  if (field.type === "textarea") {
    return `<label>${label}<textarea name="${name}" rows="4" ${required}>${escapeHtml(value || "")}</textarea></label>`;
  }

  if (field.type === "industry") {
    return `
      <fieldset class="context-fieldset industry-parent">
        <legend>
          <span>${label}</span>
          <small>${getContextLanguage() === "tr" ? "Alt sınıflandırmaları belirler" : "Controls the subcategories below"}</small>
        </legend>
        <div class="industry-selector">
          ${field.options.map((option) => {
            const optionValue = getContextOptionValue(option);
            const checked = selectedIndustry === optionValue;
            return `
              <label class="industry-card ${checked ? "selected" : ""}">
                <input type="radio" name="${name}" value="${escapeHtml(optionValue)}" ${checked ? "checked" : ""} />
                <div>
                  <strong>${escapeHtml(getContextOptionLabel(option))}</strong>
                  <p>${escapeHtml(getContextOptionDescription(option))}</p>
                </div>
                <span>${checked ? (getContextLanguage() === "tr" ? "Seçili" : "Selected") : (getContextLanguage() === "tr" ? "Seç" : "Select")}</span>
              </label>
            `;
          }).join("")}
        </div>
      </fieldset>
    `;
  }

  if (field.type === "select") {
    return `
      <label>${label}
        <select name="${name}" ${required}>
          <option value="">${getContextLanguage() === "tr" ? "Seçiniz" : "Select"}</option>
          ${field.options.map((option) => {
            const optionValue = getContextOptionValue(option);
            return `<option value="${escapeHtml(optionValue)}" ${value === optionValue ? "selected" : ""}>${escapeHtml(getContextOptionLabel(option))}</option>`;
          }).join("")}
        </select>
      </label>
    `;
  }

  if (field.type === "checkbox") {
    const selected = Array.isArray(value) ? value : [];
    const body = field.groupedOptions
      ? field.groupedOptions.map((group) => `
          <details class="checkbox-subgroup" ${group.items.some((option) => selected.includes(getContextOptionValue(option))) ? "open" : ""}>
            <summary>
              <strong>${escapeHtml(getContextCopy(group.group))}</strong>
              <span>${group.items.filter((option) => selected.includes(getContextOptionValue(option))).length}/${group.items.length}</span>
            </summary>
            <div class="checkbox-grid compact">
              ${group.items.map((option) => renderContextCheckboxOption(option, selected, name)).join("")}
            </div>
          </details>
        `).join("")
      : `
          <details class="checkbox-subgroup" ${selected.length ? "open" : ""}>
            <summary>
              <strong>${label}</strong>
              <span>${selected.length}/${field.options.length}</span>
            </summary>
            <div class="checkbox-grid compact">
              ${field.options.map((option) => renderContextCheckboxOption(option, selected, name)).join("")}
            </div>
          </details>
        `;
    return `
      <fieldset class="context-fieldset">
        <legend>
          <span>${label}</span>
          <small>${selected.length} ${getContextLanguage() === "tr" ? "seçildi" : "selected"}</small>
        </legend>
        ${body}
      </fieldset>
    `;
  }

  if (field.type === "scale") {
    return `
      <fieldset class="context-scale">
        <legend>${label}</legend>
        <div class="scale-row">
          ${[1, 2, 3, 4, 5].map((score) => `
            <label>
              <input type="radio" name="${name}" value="${score}" ${String(value || "") === String(score) ? "checked" : ""} ${required} />
              <span>${score}</span>
            </label>
          `).join("")}
        </div>
      </fieldset>
    `;
  }

  return `<label>${label}<input name="${name}" type="${field.type || "text"}" value="${escapeHtml(value || "")}" ${required} /></label>`;
}

function renderProjectContextForm() {
  const form = document.querySelector("#project-context-form");
  if (!form) return;
  const values = projectContextIntake?.contextData || {};
  form.innerHTML = `
    ${contextFieldGroups.map((group, index) => `
      <section class="context-group">
        <div class="context-group-header">
          <div class="context-step">${index + 1}</div>
          <div>
            <h3>${getContextCopy(group.title)}</h3>
            <p>${getContextCopy(contextGroupDescriptions[group.title.en] || "")}</p>
          </div>
        </div>
        <div class="form-grid">
          ${group.fields.map((field) => renderContextField(field, values)).join("")}
        </div>
      </section>
    `).join("")}
    <button class="primary-button" type="submit">${getContextLanguage() === "tr" ? "Şirket Bilgilerini Kaydet" : "Save Company Context"}</button>
  `;

  const badge = document.querySelector("#context-status-badge");
  if (badge) {
    const status = projectContextIntake?.status || "draft";
    badge.textContent = status[0].toUpperCase() + status.slice(1);
  }
  const languageInput = document.querySelector("#context-language");
  if (languageInput) languageInput.value = getContextLanguage();
  document.querySelectorAll("[data-context-language]").forEach((button) => {
    button.classList.toggle("active", button.dataset.contextLanguage === getContextLanguage());
  });
  document.querySelector("#context-recipient-name") && (document.querySelector("#context-recipient-name").value = projectContextIntake?.recipientName || "");
  document.querySelector("#context-recipient-email") && (document.querySelector("#context-recipient-email").value = projectContextIntake?.recipientEmail || "");
}

function renderContextSummary() {
  const summary = document.querySelector("#context-summary");
  if (!summary) return;
  if (!hasActiveWorkspace()) {
    summary.innerHTML = renderScreenState("context", "empty", { compact: true });
    return;
  }
  const data = projectContextIntake?.contextData || {};
  const filledCount = Object.values(data).filter((value) => Array.isArray(value) ? value.length : value).length;
  const totalCount = contextFieldGroups.reduce((sum, group) => sum + group.fields.length, 0);
  summary.innerHTML = `
    <article>
      <span>Status</span>
      <strong>${projectContextIntake?.status || "Not started"}</strong>
    </article>
    <article>
      <span>Fields Completed</span>
      <strong>${filledCount}/${totalCount}</strong>
    </article>
    <article>
      <span>Company Scale</span>
      <strong>${escapeHtml(data.employeeRange || "-")}</strong>
    </article>
    <article>
      <span>Locations</span>
      <strong>${escapeHtml(data.locationCount || "-")}</strong>
    </article>
  `;
}

function renderExecutiveScore() {
  const container = document.querySelector("#executive-score");
  if (!container) return;
  if (!hasActiveWorkspace()) {
    container.innerHTML = `
      ${renderScreenState("context", "empty", {
        title: "Select a project first",
        message: "Dashboard data is organization-specific. Open an organization workspace to see maturity scores.",
        actionLabel: "Open Organizations",
        actionView: "projects"
      })}
    `;
    return;
  }
  const allApprovedFindings = approvedFindings();
  const lens = stakeholderLensOptions(allApprovedFindings);
  const findings = filterFindingsByStakeholderLens(allApprovedFindings);
  const recommendations = approvedRecommendations();
  const roadmapItems = approvedRoadmapItems();
  const missingKpis = ownerKpiFindings(findings);
  if (!findings.length) {
    container.innerHTML = `
      ${renderScreenState("owner-dashboard", "empty", {
        title: "No approved findings yet",
        message: "Digital maturity scores will be calculated after findings are generated and approved in the Findings Workbench."
      })}
    `;
    return;
  }
  const snapshot = calculateOwnerSnapshot(findings, recommendations, roadmapItems, missingKpis);
  const dimensions = ["operations", "data", "technology", "automation", "customer_experience", "risk_management"].map((domain) => {
    const domainFindings = findings.filter((finding) => finding.business_domain === domain);
    const averagePriority = domainFindings.length
      ? domainFindings.reduce((sum, finding) => sum + Number(finding.priority_score || 0), 0) / domainFindings.length
      : 0;
    const maturityScore = domainFindings.length ? Math.max(1, Math.min(5, 5 - (averagePriority / 25))) : null;
    return [ownerDomainLabel(domain), maturityScore];
  }).filter(([, score]) => score !== null);
  container.innerHTML = `
    <div class="score-card">
      <span>Digital Maturity Score</span>
      <strong>${snapshot.digitalMaturityScore}/100</strong>
      <small>Calculated from approved findings, impact scores, confidence, and roadmap items.</small>
    </div>
    <div class="score-table">
      ${dimensions.length ? dimensions
        .map(
          ([area, score]) => `
            <div>
              <span>${area}</span>
              <strong>${score.toFixed(1)}</strong>
            </div>
          `
        )
        .join("") : "<p>No domain maturity dimensions available yet.</p>"}
    </div>
  `;
}

function renderProblemTable() {
  const table = document.querySelector("#problem-table");
  if (!table) return;
  if (!hasActiveWorkspace()) {
    const subtitle = document.querySelector("#problem-table-subtitle");
    if (subtitle) subtitle.textContent = "Organization required";
    table.innerHTML = `
      <tr>
        <td colspan="3">${renderScreenState("context", "empty", { compact: true })}</td>
      </tr>
    `;
    return;
  }
  const problemRows = approvedFindings()
    .sort((a, b) => Number(b.priority_score || 0) - Number(a.priority_score || 0))
    .slice(0, 10)
    .map((finding) => [
      finding.title,
      finding.evidence_count || evidenceForFinding(finding.id).length || 0,
      ownerPriorityLabel(finding)
    ]);
  const subtitle = document.querySelector("#problem-table-subtitle");
  if (subtitle) subtitle.textContent = "Approved findings only";
  table.innerHTML = problemRows.length ? problemRows
    .map(
      ([problem, mentions, impact]) => `
        <tr>
          <td>${escapeHtml(problem)}</td>
          <td>${mentions}</td>
          <td><span class="badge ${impact.toLowerCase()}">${impact}</span></td>
        </tr>
      `
    )
    .join("") : `
      <tr>
        <td colspan="3">${renderScreenState("owner-dashboard", "empty", { compact: true })}</td>
      </tr>
    `;
}

function renderHeatMap() {
  const container = document.querySelector("#heat-map");
  if (!container) return;
  if (!hasActiveWorkspace()) {
    container.innerHTML = `
      ${renderScreenState("context", "empty", {
        title: "No project selected",
        message: "Operational hotspots appear after opening a company workspace."
      })}
    `;
    return;
  }
  const domains = ["service_delivery", "field_operations", "inventory_management", "reporting_analytics", "technology", "workforce", "customer_experience", "risk_management"];
  const allApprovedFindings = approvedFindings();
  const lens = stakeholderLensOptions(allApprovedFindings);
  const findings = filterFindingsByStakeholderLens(allApprovedFindings);
  const rows = domains.map((domain) => {
    const domainFindings = findings.filter((finding) => finding.business_domain === domain);
    const averagePriority = domainFindings.length
      ? domainFindings.reduce((sum, finding) => sum + Number(finding.priority_score || 0), 0) / domainFindings.length
      : 0;
    const criticalCount = domainFindings.filter((finding) => Number(finding.priority_score || 0) >= 90 || Number(finding.severity || 0) >= 5).length;
    const level = criticalCount || averagePriority >= 75 ? "High" : averagePriority >= 50 ? "Medium" : "Low";
    return [ownerDomainLabel(domain), level, Math.min(100, Math.round(averagePriority)), domainFindings.length];
  }).filter(([, , , count]) => count > 0);
  container.innerHTML = rows.length ? rows
    .map(
      ([department, level, score, count]) => `
        <div class="heat-row">
          <span>${department}</span>
          <strong class="${level.toLowerCase()}">${level}</strong>
          <div class="bar"><i style="width:${score}%"></i></div>
          <small>${count} approved finding${count === 1 ? "" : "s"} · average priority ${score}</small>
        </div>
      `
    )
    .join("") : `
      ${renderScreenState("owner-dashboard", "empty", {
        title: "No approved hotspot data yet",
        message: "Operational hotspots will be calculated from approved findings grouped by business domain."
      })}
    `;
}

function renderOpportunityMatrix() {
  const container = document.querySelector("#opportunity-matrix");
  if (!container) return;
  if (!hasActiveWorkspace()) {
    const subtitle = document.querySelector("#opportunity-matrix-subtitle");
    if (subtitle) subtitle.textContent = "Organization required";
    container.innerHTML = renderScreenState("context", "empty", {
      title: "No workspace selected",
      message: "Open a project to view opportunity triggers."
    });
    return;
  }
  const approved = approvedRecommendations()
    .sort((a, b) => Number(b.priority_score || 0) - Number(a.priority_score || 0));
  const quickWins = approved.filter((item) => item.roadmap_phase === "Quick Wins" || item.recommendation_type === "Quick Win").slice(0, 5);
  const strategic = approved.filter((item) => item.roadmap_phase !== "Quick Wins" && item.recommendation_type !== "Quick Win").slice(0, 5);
  const subtitle = document.querySelector("#opportunity-matrix-subtitle");
  if (subtitle) subtitle.textContent = "Approved recommendations only";
  container.innerHTML = `
    <article>
      <h3>Quick Wins</h3>
      ${quickWins.length ? quickWins.map((item) => `<p>${escapeHtml(item.title)}</p>`).join("") : "<p>No approved quick wins yet.</p>"}
    </article>
    <article>
      <h3>Strategic / Foundation Projects</h3>
      ${strategic.length ? strategic.map((item) => `<p>${escapeHtml(item.title)}</p>`).join("") : "<p>No approved strategic recommendations yet.</p>"}
    </article>
  `;
}

function renderAssessmentManagerCommandCenter() {
  if (assessmentManagerCommandCenterError) {
    return renderScreenState("analysis", "error", {
      title: "Assessment Command Center could not load",
      message: assessmentManagerCommandCenterError,
      actionLabel: "Refresh",
      actionView: "dashboard"
    });
  }
  const state = assessmentManagerCommandCenterState;
  if (!state) return renderLoadingSkeleton("Loading Assessment Command Center", 5);
  if (!state.assigned_organization || !state.active_assessment) {
    return renderScreenState("analysis", "empty", {
      title: "No assigned active assessment",
      message: "An assigned organization and active assessment are required before collection can be coordinated.",
      actionLabel: "Refresh",
      actionView: "dashboard"
    });
  }

  const summary = state.participant_summary || {};
  const groups = state.participant_groups || {};
  const next = state.next_best_action || {};
  const complete = state.collection_status?.complete;
  const participants = state.participants || [];
  const recent = state.recent_activity || [];

  return `
    <section class="manager-command" id="manager-overview">
      <section class="panel manager-hero">
        <div>
          <span class="eyebrow">Assessment Command Center</span>
          <h2>${escapeHtml(state.assigned_organization.organization_name)}</h2>
          <p>${escapeHtml(state.collection_status?.label || "Assessment collection is in progress.")}</p>
          <div class="owner-command-meta">
            <span>Assessment: ${escapeHtml(state.active_assessment.name || "Assessment")}</span>
            <span>Framework: ${escapeHtml(state.active_assessment.framework_name || "Framework")}</span>
            <span>Role: Assessment Manager</span>
          </div>
        </div>
        <div class="manager-progress-ring">
          <strong>${Number(state.collection_status?.percent_complete || 0)}%</strong>
          <span>collection complete</span>
        </div>
      </section>

      ${complete ? `
        <section class="panel manager-handoff">
          <span class="status-pill approved">handoff ready</span>
          <h3>Collection is complete. Consultant review can begin.</h3>
          <p>No findings or recommendation approval tools are shown here. Your coordination work is complete for this assessment.</p>
        </section>
      ` : ""}

      <section class="manager-grid">
        <article class="panel manager-next-action">
          <div class="panel-header">
            <div><h2>Next Best Action</h2><span>One coordination move to make now</span></div>
          </div>
          <h3>${escapeHtml(next.label || "No action required")}</h3>
          <button class="primary-button manager-jump-action" data-manager-jump="${escapeHtml(next.target || "manager-overview")}" type="button">${escapeHtml(next.action || "Open")}</button>
        </article>
        <article class="panel" id="manager-progress">
          <div class="panel-header">
            <div><h2>Collection Snapshot</h2><span>Completion and risk signals</span></div>
          </div>
          <div class="manager-metric-grid">
            ${[
              ["Total Participants", summary.total || 0],
              ["Invited", summary.invited || 0],
              ["Started", summary.started || 0],
              ["Completed", summary.completed || 0],
              ["Overdue", summary.overdue || 0],
              ["Missing Required Roles", summary.missing_required_roles || 0]
            ].map(([label, value]) => `<article><span>${label}</span><strong>${value}</strong></article>`).join("")}
          </div>
        </article>
      </section>

      <section class="panel" id="manager-coverage">
        <div class="panel-header">
          <div><h2>Role Coverage</h2><span>Required and recommended roles only</span></div>
        </div>
        <div class="manager-role-grid">${managerRoleCoverageCards(state.role_coverage || {})}</div>
      </section>

      <section class="panel" id="manager-participants">
        <div class="panel-header">
          <div><h2>Participant Progress</h2><span>Grouped by response status</span></div>
          <div class="row-actions">
            <button class="ghost-button manager-jump-action" data-manager-jump="assessment-participant-form" type="button">Add Participant</button>
            <button class="ghost-button manager-jump-action" data-manager-jump="manager-upload" type="button">Upload Participants</button>
            <button class="ghost-button" id="create-uploaded-participant-sessions" type="button">Create Sessions</button>
          </div>
        </div>
        <div class="manager-participant-groups">
          ${managerParticipantGroup("Not Invited", groups.not_invited || [])}
          ${managerParticipantGroup("Invited, Not Started", groups.invited || [])}
          ${managerParticipantGroup("Started", groups.started || [])}
          ${managerParticipantGroup("Completed", groups.completed || [])}
          ${managerParticipantGroup("Overdue", groups.overdue || [])}
        </div>
      </section>

      <section class="panel" id="manager-upload">
      </section>

      <section class="panel" id="manager-communications">
        <div class="panel-header">
          <div><h2>Communications Summary</h2><span>Invitation and reminder health</span></div>
        </div>
        <div class="manager-metric-grid">
          ${[
            ["Invitations Sent", state.invitation_summary?.sent || 0],
            ["Failed Invitations", state.invitation_summary?.failed || 0],
            ["Not Sent", state.invitation_summary?.not_sent || 0],
            ["Reminders Sent", state.reminder_summary?.sent || 0],
            ["Failed Reminders", state.reminder_summary?.failed || 0],
            ["Last Reminder", state.reminder_summary?.last_sent_at ? new Date(state.reminder_summary.last_sent_at).toLocaleDateString() : "None"]
          ].map(([label, value]) => `<article><span>${label}</span><strong>${escapeHtml(String(value))}</strong></article>`).join("")}
        </div>
      </section>

      <section class="manager-grid">
        <article class="panel">
          <div class="panel-header"><div><h2>Stuck Participants</h2><span>Overdue or missing active link</span></div></div>
          <div class="consultant-list">
            ${(state.stuck_participants || []).length ? state.stuck_participants.slice(0, 8).map((participant) => `
              <div class="consultant-list-item">
                <span class="status-pill warning">${participant.overdue ? "Overdue" : "No Token"}</span>
                <div><strong>${escapeHtml(managerParticipantName(participant))}</strong><small>${escapeHtml(stakeholderRoleLabel(participant.stakeholder_role_id))}</small></div>
                <button class="ghost-button send-participant-reminder" data-participant-id="${escapeHtml(participant.participant_id)}" type="button">Send Reminder</button>
              </div>
            `).join("") : `<p class="upload-note">No stuck participants right now.</p>`}
          </div>
        </article>
        <article class="panel">
          <div class="panel-header"><div><h2>Recent Activity</h2><span>Collection timeline</span></div></div>
          <div class="consultant-list">
            ${recent.length ? recent.map((item) => `
              <div class="consultant-list-item">
                <span class="status-dot success"></span>
                <div><strong>${escapeHtml(item.title)}</strong><small>${new Date(item.timestamp).toLocaleString()}</small></div>
              </div>
            `).join("") : `<p class="upload-note">No recent collection activity yet.</p>`}
          </div>
        </article>
      </section>

      <section class="panel manager-hidden-boundary">
        <strong>Consultant handoff boundary</strong>
        <p>Assessment managers coordinate collection only. Findings, recommendation approval, reports, and Operations Center are intentionally hidden for this role.</p>
      </section>
    </section>
  `;
}

function compactList(items = [], emptyText = "No records yet.") {
  return items.length ? items.map((item) => `<span class="mini-chip">${escapeHtml(item)}</span>`).join("") : `<p class="upload-note">${escapeHtml(emptyText)}</p>`;
}

function organizationProfileSummaryCards() {
  const data = projectContextIntake?.data || projectContextIntake || {};
  return `
    <div class="blueprint-score-grid">
      <article><span>Organization</span><strong>${escapeHtml(getOrganizationDisplayName() || activeProject?.clientDisplayName || "Organization")}</strong></article>
      <article><span>Profile Status</span><strong>${escapeHtml(projectContextIntake?.status || companyProfile ? "Available" : "Not Started")}</strong></article>
      <article><span>Company Size</span><strong>${escapeHtml(data.employeeRange || data.company_size || companyProfile?.company_size || "-")}</strong></article>
      <article><span>Locations</span><strong>${escapeHtml(data.locationCount || data.location_count || companyProfile?.location_count || "-")}</strong></article>
    </div>
  `;
}

function renderProcesses() {
  const findings = approvedFindings();
  const processRows = Object.entries(findings.reduce((acc, finding) => {
    const domain = ownerDomainLabel(finding.business_domain || "Unknown");
    acc[domain] = acc[domain] || { count: 0, priority: 0 };
    acc[domain].count += 1;
    acc[domain].priority += Number(finding.priority_score || 0);
    return acc;
  }, {}));
  document.querySelector("#process-table").innerHTML = processRows.length
    ? processRows.map(
      ([process, data]) => {
        const score = Math.round(data.priority / data.count);
        const status = score >= 75 ? "Needs urgent attention" : score >= 50 ? "Needs attention" : "Monitored";
        return `
        <tr>
          <td>${process}</td>
          <td>${score}%</td>
          <td>${status}</td>
        </tr>
      `;
      }
    )
    .join("") : `<tr><td colspan="3">Process health will be calculated from approved findings.</td></tr>`;

  const bottleneckFindings = findings.filter((finding) => (finding.problem_types || []).includes("bottleneck"));
  document.querySelector("#bottleneck-list").innerHTML = bottleneckFindings.length
    ? bottleneckFindings.map(
      (item) => `
        <article class="analysis-card">
          <h3>${escapeHtml(item.title)}</h3>
          <p>${escapeHtml(item.description || "Bottleneck finding generated from assessment evidence.")}</p>
        </article>
      `
    )
    .join("") : `<article class="analysis-card"><h3>No approved bottlenecks yet</h3><p>Bottleneck findings will appear after evidence is analyzed and approved.</p></article>`;
}

function renderDiscoveryFramework() {
  document.querySelector("#discovery-framework").innerHTML = discoveryFramework
    .map(
      (area) => `
        <article class="framework-card">
          <div class="framework-code">${area.code}</div>
          <h3>${area.title}</h3>
          <div class="tag-list">${area.signals.map((signal) => `<span>${signal}</span>`).join("")}</div>
        </article>
      `
    )
    .join("");
}

function renderAnalysisKnowledgeMap() {
  const levels = [
    ["Level 1", "Stakeholder", analysisKnowledgeMap.stakeholders],
    ["Level 2", "Business Domain", analysisKnowledgeMap.domains],
    ["Level 3", "Assessment Category", analysisKnowledgeMap.categories],
    ["Level 4", "Problem Type", analysisKnowledgeMap.problemTypes],
    ["Level 5", "Severity", analysisKnowledgeMap.severityScale],
    ["Level 6", "Frequency", analysisKnowledgeMap.frequencies],
    ["Level 7", "Impact Dimension", analysisKnowledgeMap.impactDimensions],
    ["Level 8", "Root Cause", analysisKnowledgeMap.rootCauses],
    ["Level 9", "Opportunity Class", analysisKnowledgeMap.opportunityClasses],
    ["Level 10", "Roadmap Phase", analysisKnowledgeMap.roadmapPhases]
  ];

  document.querySelector("#analysis-knowledge-map").innerHTML = levels
    .map(
      ([level, title, items]) => `
        <article class="framework-card">
          <div class="framework-code">${level}</div>
          <h3>${title}</h3>
          <div class="tag-list">${items.slice(0, 8).map((item) => `<span>${item}</span>`).join("")}${items.length > 8 ? `<span>+${items.length - 8} more</span>` : ""}</div>
        </article>
      `
    )
    .join("");
}

function renderBusinessDomainsTaxonomy() {
  const selectedIds = getSelectedBusinessDomainIds();
  const selectedCount = businessDomainsTaxonomy.filter((domain) => selectedIds.has(domain.id)).length;
  const container = document.querySelector("#business-domain-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>${selectedCount}/${businessDomainsTaxonomy.length} domains selected</strong>
      <span>Layer 3 scope for question selection and AI analysis.</span>
    </div>
    <div class="business-domain-grid">
      ${businessDomainsTaxonomy
        .map((domain) => {
          const checked = selectedIds.has(domain.id);
          return `
            <label class="business-domain-card ${checked ? "selected" : ""}">
              <input type="checkbox" name="business_domain" value="${domain.id}" ${checked ? "checked" : ""} />
              <span class="domain-card-title">${domain.name}</span>
              <span class="domain-card-description">${domain.description}</span>
              <span class="domain-card-subdomains">${domain.subdomains.slice(0, 4).join(" / ")}${domain.subdomains.length > 4 ? ` / +${domain.subdomains.length - 4}` : ""}</span>
            </label>
          `;
        })
        .join("")}
    </div>
  `;
}

function renderAssessmentCategoriesTaxonomy() {
  const selectedIds = getSelectedAssessmentCategoryIds();
  const selectedCount = assessmentCategoriesTaxonomy.filter((category) => selectedIds.has(category.id)).length;
  const container = document.querySelector("#assessment-category-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>${selectedCount}/${assessmentCategoriesTaxonomy.length} categories selected</strong>
      <span>Layer 4 classification for questions, responses, and AI findings.</span>
    </div>
    <div class="assessment-rule-strip">
      ${["Stakeholder", "Business Domain", "Assessment Category", "Problem Type", "Severity", "Frequency", "Impact", "Recommendation"]
        .map((item, index) => `<span>${index + 1}. ${item}</span>`)
        .join("")}
    </div>
    <div class="assessment-category-grid">
      ${assessmentCategoriesTaxonomy
        .map((category) => {
          const checked = selectedIds.has(category.id);
          return `
            <label class="assessment-category-card ${checked ? "selected" : ""}">
              <input type="checkbox" name="assessment_category" value="${category.id}" ${checked ? "checked" : ""} />
              <span class="domain-card-title">${category.name}</span>
              <span class="domain-card-description">${category.description}</span>
            </label>
          `;
        })
        .join("")}
    </div>
  `;
}

function renderProblemTypesTaxonomy() {
  const selectedIds = getSelectedProblemTypeIds();
  const totalCount = problemTypesTaxonomy.reduce((sum, group) => sum + group.items.length, 0);
  const selectedCount = getProblemTypeOptions().filter((problemType) => selectedIds.has(problemType.id)).length;
  const container = document.querySelector("#problem-type-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>${selectedCount}/${totalCount} problem types selected</strong>
      <span>Layer 5 evidence tags for AI clustering, ranking, and recommendations.</span>
    </div>
    <div class="problem-example-card">
      <strong>Example AI classification</strong>
      <span>WhatsApp job intake + Excel re-entry + ERP entry = WhatsApp Dependency, Duplicate Activity, Spreadsheet Dependency, Missing Integration.</span>
    </div>
    <div class="problem-type-group-grid">
      ${problemTypesTaxonomy
        .map((group) => `
          <section class="problem-type-group">
            <div class="problem-type-group-header">
              <h3>${group.group}</h3>
              <span>${group.items.filter((item) => selectedIds.has(item.id)).length}/${group.items.length}</span>
            </div>
            <div class="problem-type-list">
              ${group.items
                .map((item) => {
                  const checked = selectedIds.has(item.id);
                  return `
                    <label class="problem-type-chip ${checked ? "selected" : ""}">
                      <input type="checkbox" name="problem_type" value="${item.id}" ${checked ? "checked" : ""} />
                      <span>${item.name}</span>
                    </label>
                  `;
                })
                .join("")}
            </div>
          </section>
        `)
        .join("")}
    </div>
  `;
}

function renderImpactModel() {
  const container = document.querySelector("#impact-model-taxonomy");
  if (!container) return;
  const examples = [
    {
      title: "WhatsApp + Excel + ERP Re-entry",
      problem_type: "whatsapp_dependency",
      severity: 4,
      frequency: 5,
      time_impact: 4,
      cost_impact: 3,
      customer_impact: 3,
      revenue_impact: 2,
      risk_impact: 2,
      employee_impact: 5,
      automation_potential: 5
    },
    {
      title: "Roadside Assistance Dispatch Automation",
      problem_type: "manual_process",
      severity: 5,
      frequency: 4,
      time_impact: 5,
      cost_impact: 4,
      customer_impact: 5,
      revenue_impact: 4,
      risk_impact: 5,
      employee_impact: 3,
      automation_potential: 5
    }
  ].map((example) => {
    const priorityScore = calculatePriorityScore(example);
    return { ...example, priority_score: priorityScore, classification: classifyPriority(priorityScore) };
  });

  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>Layer 6 Impact & Prioritization Model</strong>
      <span>Turns each finding into a 0-100 priority score and roadmap signal.</span>
    </div>
    <div class="impact-layout">
      <section class="impact-block">
        <h3>Impact Dimensions</h3>
        <div class="impact-dimension-grid">
          ${impactModel.dimensions
            .map(
              (dimension) => `
                <article class="impact-dimension-card">
                  <strong>${dimension.name}</strong>
                  <p>${dimension.description}</p>
                  <span>1 ${dimension.scale[1]} / 3 ${dimension.scale[3]} / 5 ${dimension.scale[5]}</span>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Scoring Dimensions</h3>
        <div class="score-scale-grid">
          ${[
            ["Severity", scoringModel.severity],
            ["Frequency", scoringModel.frequency],
            ["Automation Potential", scoringModel.automationPotential]
          ]
            .map(
              ([title, scale]) => `
                <article class="score-scale-card">
                  <strong>${title}</strong>
                  <div>${Object.entries(scale).map(([score, label]) => `<span>${score}. ${label}</span>`).join("")}</div>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Priority Formula</h3>
        <div class="formula-card">
          <code>(Severity x 0.30 + Frequency x 0.20 + Customer x 0.15 + Revenue x 0.15 + Cost x 0.10 + Risk x 0.10) x 20</code>
          <span>Output: 0-100</span>
        </div>
        <div class="classification-grid">
          ${scoringModel.classificationBands
            .map((band) => `<span><strong>${band.min}-${band.max}</strong>${band.label}</span>`)
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Calculated Examples</h3>
        <div class="impact-example-grid">
          ${examples
            .map(
              (example) => `
                <article class="impact-example-card">
                  <strong>${example.title}</strong>
                  <p>${example.problem_type}</p>
                  <div class="priority-meter">
                    <i style="width:${example.priority_score}%"></i>
                  </div>
                  <span>${example.priority_score}/100 · ${example.classification}</span>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Finding Output Object</h3>
        <div class="output-field-grid">
          ${scoringModel.findingOutputFields.map((field) => `<span>${field}</span>`).join("")}
        </div>
      </section>
    </div>
  `;
}

function renderRecommendationEngine() {
  const container = document.querySelector("#recommendation-engine-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>Layer 7 Recommendation Engine</strong>
      <span>Transforms prioritized findings into initiatives, projects, and roadmap programs.</span>
    </div>
    <div class="impact-layout">
      <section class="impact-block">
        <h3>Recommendation Types</h3>
        <div class="recommendation-type-grid">
          ${recommendationEngine.types
            .map(
              (type) => `
                <article class="recommendation-type-card">
                  <strong>${type.name}</strong>
                  <span>${type.timeline}</span>
                  <p>${type.description}</p>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Recommendation Categories</h3>
        <div class="output-field-grid">
          ${recommendationEngine.categories.map((category) => `<span>${category}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>AI Mapping Rules</h3>
        <div class="mapping-rule-grid">
          ${recommendationEngine.mappingRules
            .map(
              (rule) => `
                <article class="mapping-rule-card">
                  <div class="tag-list">${rule.problemTypes.map((type) => `<span>${type}</span>`).join("")}</div>
                  <strong>${rule.recommendation}</strong>
                  <p>${rule.expectedBenefit}</p>
                  <span>${rule.category} · ${rule.effort} effort</span>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Recommendation Scoring</h3>
        <div class="score-scale-grid">
          ${[
            ["Effort Score", recommendationEngine.scoring.effortScore],
            ["Business Value Score", recommendationEngine.scoring.businessValueScore],
            ["Implementation Risk Score", recommendationEngine.scoring.implementationRiskScore]
          ]
            .map(
              ([title, scale]) => `
                <article class="score-scale-card">
                  <strong>${title}</strong>
                  <div>${Object.entries(scale).map(([score, label]) => `<span>${score}. ${label}</span>`).join("")}</div>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Opportunity Matrix</h3>
        <div class="opportunity-zone-grid">
          ${recommendationEngine.opportunityMatrix
            .map(
              (zone) => `
                <article class="opportunity-zone-card">
                  <strong>${zone.zone}</strong>
                  <span>${zone.rule}</span>
                  <div class="tag-list">${zone.examples.map((example) => `<span>${example}</span>`).join("")}</div>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Framework Demo: Fleet & Service Operations</h3>
        <article class="krb-recommendation-example">
          <div>
            <strong>${recommendationEngine.krbExample.title}</strong>
            <span>${recommendationEngine.krbExample.recommendation_type} · ${recommendationEngine.krbExample.estimated_timeline}</span>
          </div>
          <p>${recommendationEngine.krbExample.expected_benefit}</p>
          <div class="priority-meter">
            <i style="width:${recommendationEngine.krbExample.priority_score}%"></i>
          </div>
          <div class="tag-list">
            ${recommendationEngine.krbExample.problem_types.map((type) => `<span>${type}</span>`).join("")}
            <span>${recommendationEngine.krbExample.recommendation_category}</span>
            <span>${recommendationEngine.krbExample.roadmap_phase}</span>
          </div>
        </article>
      </section>
      <section class="impact-block">
        <h3>Recommendation Output Object</h3>
        <div class="output-field-grid">
          ${recommendationEngine.outputFields.map((field) => `<span>${field}</span>`).join("")}
        </div>
      </section>
    </div>
  `;
}

function renderRoadmapGenerator() {
  const container = document.querySelector("#roadmap-generator-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>Layer 8 Roadmap Generator</strong>
      <span>Converts recommendations into an executable transformation plan.</span>
    </div>
    <div class="impact-layout">
      <section class="impact-block">
        <h3>Roadmap Phases</h3>
        <div class="roadmap-phase-grid">
          ${roadmapGenerator.phases
            .map(
              (phase) => `
                <article class="roadmap-phase-card">
                  <strong>${phase.name}</strong>
                  <span>${phase.timeline}</span>
                  <p>${phase.objective}</p>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>AI Roadmap Placement Rules</h3>
        <div class="mapping-rule-grid">
          ${roadmapGenerator.placementRules
            .map(
              (rule) => `
                <article class="mapping-rule-card">
                  <strong>${rule.phase}</strong>
                  <p>${rule.criteria}</p>
                  <div class="tag-list">${rule.examples.map((example) => `<span>${example}</span>`).join("")}</div>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Dependency Guardrail</h3>
        <article class="dependency-card">
          <strong>${roadmapGenerator.dependencyRule.initiative}</strong>
          <p>AI should not place advanced initiatives before prerequisite capabilities exist.</p>
          <div class="tag-list">${roadmapGenerator.dependencyRule.dependsOn.map((item) => `<span>${item}</span>`).join("")}</div>
        </article>
      </section>
      <section class="impact-block">
        <h3>Roadmap Themes</h3>
        <div class="output-field-grid">
          ${roadmapGenerator.themes.map((theme) => `<span>${theme}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Framework Demo Roadmap</h3>
        <div class="krb-roadmap-grid">
          ${roadmapGenerator.krbRoadmap
            .map(
              (phase) => `
                <article class="krb-roadmap-phase">
                  <strong>${phase.phase}</strong>
                  ${phase.groups
                    .map(
                      (group) => `
                        <div>
                          <span>${group.theme}</span>
                          <ul>${group.items.map((item) => `<li>${item}</li>`).join("")}</ul>
                        </div>
                      `
                    )
                    .join("")}
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Portfolio Summary</h3>
        <div class="portfolio-summary-grid">
          <article><strong>${roadmapGenerator.portfolioSummary.quickWins}</strong><span>Quick Wins</span></article>
          <article><strong>${roadmapGenerator.portfolioSummary.foundationProjects}</strong><span>Foundation Projects</span></article>
          <article><strong>${roadmapGenerator.portfolioSummary.optimizationProjects}</strong><span>Optimization Projects</span></article>
          <article><strong>${roadmapGenerator.portfolioSummary.transformationProjects}</strong><span>Transformation Projects</span></article>
        </div>
      </section>
      <section class="impact-block">
        <h3>Executive Output</h3>
        <div class="output-field-grid">
          ${roadmapGenerator.executiveOutput.map((item) => `<span>${item}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Expected Business Outcomes</h3>
        <div class="output-field-grid">
          ${roadmapGenerator.expectedBusinessOutcomes.map((item) => `<span>${item}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Roadmap Item Output Object</h3>
        <div class="output-field-grid">
          ${roadmapGenerator.outputFields.map((field) => `<span>${field}</span>`).join("")}
        </div>
      </section>
    </div>
  `;
}

function renderExecutiveIntelligence() {
  const container = document.querySelector("#executive-intelligence-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>Layer 9 Executive Intelligence & Benchmarking</strong>
      <span>Turns assessment output into executive-level decisions, benchmarks, ROI, and business health signals.</span>
    </div>
    <div class="impact-layout">
      <section class="impact-block">
        <h3>Core Components</h3>
        <div class="output-field-grid">
          ${executiveIntelligence.components.map((component) => `<span>${component}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Digital Maturity Model</h3>
        <div class="score-scale-grid">
          <article class="score-scale-card">
            <strong>Maturity Dimensions</strong>
            <div>${executiveIntelligence.maturityDimensions.map((dimension) => `<span>${dimension}</span>`).join("")}</div>
          </article>
          <article class="score-scale-card">
            <strong>Maturity Scale</strong>
            <div>${Object.entries(executiveIntelligence.maturityScale).map(([score, label]) => `<span>${score}. ${label}</span>`).join("")}</div>
          </article>
        </div>
        <div class="maturity-example-grid">
          ${Object.entries(executiveIntelligence.maturityExample)
            .map(
              ([dimension, score]) => `
                <article>
                  <strong>${dimension}</strong>
                  <div class="priority-meter"><i style="width:${(score / 5) * 100}%"></i></div>
                  <span>${score.toFixed(1)}/5</span>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Industry Benchmarking</h3>
        <article class="benchmark-profile-card">
          <strong>${executiveIntelligence.benchmarkProfile.industry}</strong>
          <span>${executiveIntelligence.benchmarkProfile.size}</span>
          <div class="tag-list">${executiveIntelligence.benchmarkProfile.complexity.map((item) => `<span>${item}</span>`).join("")}</div>
        </article>
        <div class="benchmark-grid">
          ${Object.entries(executiveIntelligence.benchmarkResult)
            .map(
              ([area, result]) => `
                <article class="benchmark-card">
                  <strong>${area.replaceAll("_", " ")}</strong>
                  <div><span>Company</span><b>${result.company_score}</b></div>
                  <div><span>Industry Avg</span><b>${result.industry_average}</b></div>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Executive Intelligence Signals</h3>
        <div class="executive-signal-grid">
          ${[
            ["Strengths", executiveIntelligence.strengths.map((item) => item.title)],
            ["Weaknesses", executiveIntelligence.weaknesses.map((item) => item.title)],
            ["Opportunities", executiveIntelligence.opportunities.map((item) => `${item.title} · ${item.timeframe}`)],
            ["Risks", executiveIntelligence.risks.map((item) => `${item.title} · ${item.severity}`)]
          ]
            .map(
              ([title, items]) => `
                <article>
                  <strong>${title}</strong>
                  <ul>${items.map((item) => `<li>${item}</li>`).join("")}</ul>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>ROI Forecasting Example</h3>
        <article class="roi-card">
          <strong>${executiveIntelligence.roiExample.initiative}</strong>
          <div>
            <span>Current ${executiveIntelligence.roiExample.currentState.hoursPerWeek} hrs/week</span>
            <span>Future ${executiveIntelligence.roiExample.futureState.hoursPerWeek} hrs/week</span>
            <span>${executiveIntelligence.roiExample.estimatedSavings.annualHours} annual hours saved</span>
          </div>
        </article>
      </section>
      <section class="impact-block">
        <h3>Executive Scorecard</h3>
        <div class="portfolio-summary-grid">
          <article><strong>${executiveIntelligence.scorecard.overallMaturity}</strong><span>Overall Maturity</span></article>
          <article><strong>${executiveIntelligence.scorecard.strengthCount}</strong><span>Strengths</span></article>
          <article><strong>${executiveIntelligence.scorecard.criticalIssues}</strong><span>Critical Issues</span></article>
          <article><strong>${executiveIntelligence.scorecard.quickWins}</strong><span>Quick Wins</span></article>
          <article><strong>${executiveIntelligence.scorecard.majorProjects}</strong><span>Major Projects</span></article>
          <article><strong>${executiveIntelligence.scorecard.strategicInitiatives}</strong><span>Strategic Initiatives</span></article>
        </div>
      </section>
      <section class="impact-block">
        <h3>Framework Demo Executive Output</h3>
        <div class="executive-signal-grid">
          ${[
            ["Strengths", executiveIntelligence.krbOutput.strengths],
            ["Weaknesses", executiveIntelligence.krbOutput.weaknesses],
            ["Top Opportunities", executiveIntelligence.krbOutput.topOpportunities],
            ["Estimated Outcomes", executiveIntelligence.krbOutput.estimatedOutcomes]
          ]
            .map(
              ([title, items]) => `
                <article>
                  <strong>${title}</strong>
                  <ul>${items.map((item) => `<li>${item}</li>`).join("")}</ul>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Owner Deliverables</h3>
        <div class="output-field-grid">
          ${executiveIntelligence.deliverables.map((deliverable) => `<span>${deliverable}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Executive Narrative</h3>
        <div class="output-field-grid">
          ${executiveIntelligence.executiveNarrative.map((section) => `<span>${section}</span>`).join("")}
        </div>
      </section>
    </div>
  `;
}

function renderContinuousImprovementEngine() {
  const container = document.querySelector("#continuous-improvement-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>Layer 10 Continuous Improvement Engine</strong>
      <span>Turns assessment into an ongoing management system: assess, improve, measure, reassess, and improve again.</span>
    </div>
    <div class="impact-layout">
      <section class="impact-block">
        <h3>Core Mission</h3>
        <div class="output-field-grid">
          ${continuousImprovementEngine.mission.map((item) => `<span>${item}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Continuous Improvement Framework</h3>
        <div class="output-field-grid">
          ${continuousImprovementEngine.framework.map((item) => `<span>${item}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Initiative Tracking</h3>
        <article class="initiative-tracker-card">
          <div>
            <strong>${continuousImprovementEngine.initiativeExample.title}</strong>
            <span>${continuousImprovementEngine.initiativeExample.owner}</span>
          </div>
          <div class="priority-meter"><i style="width:${continuousImprovementEngine.initiativeExample.completionPercentage}%"></i></div>
          <span>${continuousImprovementEngine.initiativeExample.status} · ${continuousImprovementEngine.initiativeExample.completionPercentage}% complete</span>
        </article>
        <div class="output-field-grid">
          ${continuousImprovementEngine.initiativeStatus.map((status) => `<span>${status}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>KPI Tracking</h3>
        <article class="kpi-tracking-card">
          <strong>${continuousImprovementEngine.kpiExample.name}</strong>
          <div>
            <span>Before ${continuousImprovementEngine.kpiExample.before} ${continuousImprovementEngine.kpiExample.unit}</span>
            <span>After ${continuousImprovementEngine.kpiExample.after} ${continuousImprovementEngine.kpiExample.unit}</span>
            <span>${continuousImprovementEngine.kpiExample.improvement}% improvement</span>
          </div>
        </article>
        <div class="output-field-grid">
          ${continuousImprovementEngine.kpiCategories.map((category) => `<span>${category}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Maturity Evolution</h3>
        <div class="maturity-evolution-grid">
          ${continuousImprovementEngine.maturityEvolutionExample
            .map(
              (item) => `
                <article>
                  <strong>${item.domain}</strong>
                  <span>Q1 ${item.q1} → Q2 ${item.q2}</span>
                  <div class="priority-meter"><i style="width:${(item.q2 / 5) * 100}%"></i></div>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Pulse Surveys</h3>
        <div class="pulse-survey-grid">
          ${continuousImprovementEngine.pulseSurveys
            .map(
              (survey) => `
                <article>
                  <strong>${survey.audience}</strong>
                  <ul>${survey.questions.map((question) => `<li>${question}</li>`).join("")}</ul>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Opportunity Detection</h3>
        <article class="dependency-card">
          <strong>${continuousImprovementEngine.opportunityDetection.title}</strong>
          <p>${continuousImprovementEngine.opportunityDetection.reason}</p>
          <div class="tag-list"><span>${continuousImprovementEngine.opportunityDetection.priority} Priority</span></div>
        </article>
      </section>
      <section class="impact-block">
        <h3>Executive Alerts</h3>
        <div class="executive-alert-grid">
          ${continuousImprovementEngine.executiveAlerts
            .map(
              (alert) => `
                <article>
                  <strong>${alert.type}</strong>
                  <p>${alert.message}</p>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Benchmark Evolution</h3>
        <div class="benchmark-grid">
          ${Object.entries(continuousImprovementEngine.benchmarkTrend)
            .map(
              ([area, trend]) => `
                <article class="benchmark-card">
                  <strong>${area.replaceAll("_", " ")}</strong>
                  <div><span>Previous</span><b>${trend.previous}</b></div>
                  <div><span>Current</span><b>${trend.current}</b></div>
                  <div><span>Industry Avg</span><b>${trend.industry_average}</b></div>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Business Health Score</h3>
        <article class="business-health-card">
          <strong>${continuousImprovementEngine.businessHealthScore.overallScore}</strong>
          <span>${continuousImprovementEngine.businessHealthScore.status} · ${continuousImprovementEngine.businessHealthScore.trend}</span>
        </article>
      </section>
      <section class="impact-block">
        <h3>Executive Dashboard</h3>
        <div class="output-field-grid">
          ${continuousImprovementEngine.ownerDashboard.map((item) => `<span>${item}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Commercial Model</h3>
        <div class="commercial-model-grid">
          ${continuousImprovementEngine.commercialModel
            .map(
              (item) => `
                <article>
                  <strong>${item.product}</strong>
                  <span>${item.revenueModel}</span>
                </article>
              `
            )
            .join("")}
        </div>
        <div class="output-field-grid">
          ${continuousImprovementEngine.subscriptionIncludes.map((item) => `<span>${item}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Final Architecture</h3>
        <div class="output-field-grid">
          ${continuousImprovementEngine.finalArchitecture.map((layer) => `<span>${layer}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>AI Business Operating System Capabilities</h3>
        <div class="output-field-grid">
          ${continuousImprovementEngine.operatingSystemCapabilities.map((capability) => `<span>${capability}</span>`).join("")}
        </div>
      </section>
    </div>
  `;
}

function renderQuestionFramework() {
  const container = document.querySelector("#question-framework-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>Layer 11 Question Definition Schema</strong>
      <span>Ensures every question is analyzable, scoreable, KPI-aware, and recommendation-ready.</span>
    </div>
    <div class="impact-layout">
      <section class="impact-block">
        <h3>Schema Fields</h3>
        <div class="schema-field-grid">
          ${Object.entries(questionFramework.schema)
            .map(
              ([field, value]) => `
                <article>
                  <strong>${field}</strong>
                  <span>${Array.isArray(value) ? "array" : typeof value === "boolean" ? "boolean" : typeof value === "number" ? "number" : value}</span>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Simple Meaning</h3>
        <div class="output-field-grid">
          ${questionFramework.meanings.map((meaning) => `<span>${meaning}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Question Library Build Order</h3>
        <div class="question-build-grid">
          ${questionFramework.buildOrder
            .map(
              (item) => `
                <article>
                  <strong>${item.phase}</strong>
                  <span>${item.stakeholder}</span>
                  <b>${item.targetQuestions} questions</b>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Metric-First Rule</h3>
        <div class="output-field-grid">
          ${questionFramework.metricFirstRule.map((rule) => `<span>${rule}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Example Question Object</h3>
        <article class="question-example-card">
          <div>
            <strong>${questionFramework.exampleQuestion.id}</strong>
            <span>${questionFramework.exampleQuestion.stakeholder_role} · ${questionFramework.exampleQuestion.business_domain}</span>
          </div>
          <p>${questionFramework.exampleQuestion.question_text}</p>
          <div class="tag-list">
            <span>${questionFramework.exampleQuestion.question_type}</span>
            <span>${questionFramework.exampleQuestion.assessment_category}</span>
            <span>${questionFramework.exampleQuestion.roadmap_relevance}</span>
          </div>
        </article>
        <div class="question-object-grid">
          ${Object.entries(questionFramework.exampleQuestion)
            .filter(([field]) => !["id", "stakeholder_role", "business_domain", "question_text", "question_type", "assessment_category", "roadmap_relevance"].includes(field))
            .map(
              ([field, value]) => `
                <article>
                  <strong>${field}</strong>
                  <span>${Array.isArray(value) ? value.join(", ") : String(value)}</span>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
    </div>
  `;
}

function renderAnswerInterpretationModel() {
  const container = document.querySelector("#answer-interpretation-taxonomy");
  if (!container) return;
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>Layer 12 Answer Interpretation & Evidence Model</strong>
      <span>Transforms raw answers into evidence-backed findings that can drive recommendations, roadmaps, and executive intelligence.</span>
    </div>
    <div class="impact-layout">
      <section class="impact-block">
        <h3>Core Output</h3>
        <div class="output-field-grid">
          ${answerInterpretationModel.purpose.map((item) => `<span>${item}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Transformation Flow</h3>
        <div class="interpretation-flow">
          ${answerInterpretationModel.transformationFlow.map((step, index) => `<span>${index + 1}. ${step}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Finding Object</h3>
        <div class="schema-field-grid">
          ${Object.keys(answerInterpretationModel.findingObject).map((field) => `<article><strong>${field}</strong><span>finding.${field}</span></article>`).join("")}
        </div>
        <article class="question-example-card">
          <div>
            <strong>${answerInterpretationModel.findingExample.title}</strong>
            <span>Generated finding</span>
          </div>
          <p>${answerInterpretationModel.findingExample.response}</p>
          <div class="tag-list">
            ${answerInterpretationModel.findingExample.problem_types.map((type) => `<span>${type}</span>`).join("")}
          </div>
        </article>
      </section>
      <section class="impact-block">
        <h3>Evidence Model</h3>
        <div class="schema-field-grid">
          ${Object.keys(answerInterpretationModel.evidenceObject).map((field) => `<article><strong>${field}</strong><span>evidence.${field}</span></article>`).join("")}
        </div>
        <div class="output-field-grid">
          ${answerInterpretationModel.evidenceTypes.map((type) => `<span>${type}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Interpretation Scales</h3>
        <div class="score-scale-grid">
          ${[
            ["Confidence", answerInterpretationModel.confidenceScale],
            ["Frequency", answerInterpretationModel.frequencyScale],
            ["Severity", answerInterpretationModel.severityScale],
            ["Stakeholder Agreement", answerInterpretationModel.stakeholderAgreementScale]
          ]
            .map(
              ([title, scale]) => `
                <article class="score-scale-card">
                  <strong>${title}</strong>
                  <div>${Object.entries(scale).map(([score, label]) => `<span>${score}. ${label}</span>`).join("")}</div>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Stakeholder Agreement</h3>
        <article class="dependency-card">
          <strong>${answerInterpretationModel.stakeholderAgreementExample.issue}</strong>
          <p>Agreement increases recommendation confidence when multiple groups identify the same issue.</p>
          <div class="tag-list">
            ${answerInterpretationModel.stakeholderAgreementExample.stakeholders.map((stakeholder) => `<span>${stakeholder}</span>`).join("")}
            <span>${answerInterpretationModel.stakeholderAgreementExample.stakeholder_agreement} Agreement</span>
          </div>
        </article>
      </section>
      <section class="impact-block">
        <h3>Contradiction Detection</h3>
        <article class="contradiction-card">
          <strong>${answerInterpretationModel.contradictionExample.contradiction_type}</strong>
          <span>contradiction_detected: ${answerInterpretationModel.contradictionExample.contradiction_detected}</span>
          <ul>${answerInterpretationModel.contradictionExample.perceptions.map((item) => `<li>${item}</li>`).join("")}</ul>
        </article>
      </section>
      <section class="impact-block">
        <h3>Finding Aggregation</h3>
        <article class="aggregation-card">
          <strong>${answerInterpretationModel.aggregationExample.finding}</strong>
          <span>${answerInterpretationModel.aggregationExample.evidence_count} evidence items</span>
          <div class="tag-list">
            ${answerInterpretationModel.aggregationExample.signals.map((signal) => `<span>${signal}</span>`).join("")}
          </div>
        </article>
      </section>
      <section class="impact-block">
        <h3>Impact Attribution</h3>
        <div class="schema-field-grid">
          ${Object.entries(answerInterpretationModel.impactExample).map(([field, score]) => `<article><strong>${field}</strong><span>${score}/5</span></article>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Recommendation Eligibility</h3>
        <article class="question-example-card">
          <div>
            <strong>${answerInterpretationModel.recommendationEligibilityExample.finding}</strong>
            <span>automation potential ${answerInterpretationModel.recommendationEligibilityExample.automation_potential}/5</span>
          </div>
          <p>recommendation_eligible: ${answerInterpretationModel.recommendationEligibilityExample.recommendation_eligible}</p>
        </article>
      </section>
      <section class="impact-block">
        <h3>AI Output Object</h3>
        <div class="output-field-grid">
          ${Object.keys(answerInterpretationModel.outputObject).map((field) => `<span>${field}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Success Criteria</h3>
        <div class="output-field-grid">
          ${answerInterpretationModel.successCriteria.map((criterion) => `<span>${criterion}</span>`).join("")}
        </div>
      </section>
    </div>
  `;
}

function getCompanyProfileModel() {
  if (assessmentEngineState?.companyProfile) return assessmentEngineState.companyProfile;
  if (companyProfile) return companyProfile;
  const data = projectContextIntake?.contextData || {};
  if (!Object.keys(data).length) return null;
  const businessActivities = Array.isArray(data.tireIndustryActivities) ? data.tireIndustryActivities : [];
  const operationalCharacteristics = Array.isArray(data.operationalCharacteristics) ? data.operationalCharacteristics : [];
  const strategicPriorities = Array.isArray(data.topPriorities) ? data.topPriorities : [];
  const signals = [...new Set([...businessActivities, ...operationalCharacteristics, ...strategicPriorities])];
  const roleMap = {
    roadside_tire_assistance: ["operations_manager", "dispatcher", "technician", "branch_manager"],
    mobile_tire_services: ["operations_manager", "dispatcher", "technician", "branch_manager"],
    fleet_tire_management: ["operations_manager", "dispatcher", "technician", "branch_manager", "fleet_customer"],
    warehouse_operations: ["warehouse_manager", "inventory_coordinator"],
    inventory_intensive: ["warehouse_manager", "inventory_coordinator", "supplier"],
    profitability_improvement: ["finance_manager"],
    data_reporting_improvement: ["finance_manager", "it_manager"],
    tire_retreading: ["operations_manager", "warehouse_manager"],
    revenue_growth: ["sales_manager"],
    customer_retention: ["sales_manager", "fleet_customer"],
    b2b_business: ["sales_manager"],
    contract_based_revenue: ["sales_manager", "finance_manager"],
    fleet_customer_focus: ["sales_manager", "fleet_customer"],
    service_network_management: ["service_partner", "fleet_customer"],
    external_service_partners: ["service_partner"],
    supplier_dependency: ["supplier"],
    procurement_complexity: ["supplier"],
    manufacturing: ["supplier"],
    distribution_network: ["supplier"],
    automation: ["it_manager"],
    system_integration: ["it_manager"],
    ai_adoption: ["it_manager"],
    AI_adoption: ["it_manager"],
    digital_transformation: ["it_manager"],
    workforce_productivity: ["hr_manager"],
    growth: ["hr_manager"],
    scaling: ["hr_manager"],
    change_management: ["hr_manager"],
    retention: ["hr_manager"],
    training: ["hr_manager"]
  };
  const questionRoleMap = {
    roadside_tire_assistance: ["operations_manager", "branch_manager", "dispatcher", "technician"],
    mobile_tire_services: ["operations_manager", "branch_manager", "dispatcher", "technician"],
    fleet_tire_management: ["operations_manager", "branch_manager", "dispatcher", "technician"],
    warehouse_operations: ["warehouse_manager", "inventory_coordinator"],
    inventory_intensive: ["warehouse_manager", "inventory_coordinator", "supplier"],
    data_reporting_improvement: ["operations_manager", "branch_manager", "dispatcher", "technician", "finance_manager", "it_manager"],
    profitability_improvement: ["operations_manager", "finance_manager", "sales_manager"],
    revenue_growth: ["sales_manager"],
    customer_retention: ["sales_manager", "fleet_customer"],
    b2b_business: ["sales_manager"],
    contract_based_revenue: ["sales_manager", "finance_manager"],
    fleet_customer_focus: ["sales_manager", "fleet_customer"],
    service_network_management: ["service_partner", "fleet_customer"],
    external_service_partners: ["service_partner"],
    supplier_dependency: ["supplier"],
    procurement_complexity: ["supplier"],
    manufacturing: ["supplier"],
    distribution_network: ["supplier"],
    automation: ["it_manager"],
    system_integration: ["it_manager"],
    ai_adoption: ["it_manager"],
    AI_adoption: ["it_manager"],
    digital_transformation: ["it_manager"],
    workforce_productivity: ["hr_manager"],
    growth: ["hr_manager"],
    scaling: ["hr_manager"],
    change_management: ["hr_manager"],
    retention: ["hr_manager"],
    training: ["hr_manager"]
  };
  const kpiMap = kpiMetricLibrary.recommendationRules || {};
  const recommendedRoleIds = new Set();
  const recommendedQuestionRoleIds = new Set();
  const recommendedKpiIds = new Set();
  signals.forEach((signal) => {
    (roleMap[signal] || []).forEach((roleId) => recommendedRoleIds.add(roleId));
    (questionRoleMap[signal] || []).forEach((roleId) => recommendedQuestionRoleIds.add(roleId));
    (kpiMap[signal] || []).forEach((kpiIdValue) => recommendedKpiIds.add(kpiIdValue));
  });
  return {
    industry: data.industry || "tire_industry",
    companyName: data.companyName || "",
    employeeRange: data.employeeRange || "",
    locationCount: data.locationCount || "",
    businessActivities,
    tireSegmentsServed: Array.isArray(data.tireSegmentsServed) ? data.tireSegmentsServed : [],
    operationalCharacteristics,
    strategicPriorities,
    workforceStructure: {
      departments: Array.isArray(data.departments) ? data.departments : [],
      managerCount: data.managerCount || "",
      fieldEmployeeCount: data.fieldEmployeeCount || "",
      operatingModel: Array.isArray(data.operatingModel) ? data.operatingModel : []
    },
    currentSystems: {
      erpSystem: data.erpSystem || "",
      crmSystem: data.crmSystem || "",
      accountingSystem: data.accountingSystem || "",
      communicationTools: Array.isArray(data.communicationTools) ? data.communicationTools : [],
      dailySystemCount: data.dailySystemCount || ""
    },
    recommendedStakeholderRoles: [...recommendedRoleIds].map((roleId) => questionBankRoles.find((role) => role.roleId === roleId)).filter(Boolean),
    recommendedQuestionRoles: [...recommendedQuestionRoleIds].map((roleId) => questionBankRoles.find((role) => role.roleId === roleId)).filter(Boolean),
    recommendedKpis: [...recommendedKpiIds].map((id) => ({ id, name: id.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase()) }))
  };
}

function labelList(values = [], fallback = "None selected") {
  const list = Array.isArray(values) ? values : [];
  return list.length ? list.map((item) => String(item).replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase())).join(", ") : fallback;
}

function getKpiProfileSignals() {
  const profile = getCompanyProfileModel();
  if (profile) {
    return new Set([
      ...(Array.isArray(profile.businessActivities) ? profile.businessActivities : []),
      ...(Array.isArray(profile.operationalCharacteristics) ? profile.operationalCharacteristics : []),
      ...(Array.isArray(profile.strategicPriorities) ? profile.strategicPriorities : [])
    ]);
  }
  const data = projectContextIntake?.contextData || {};
  return new Set([
    ...(Array.isArray(data.tireIndustryActivities) ? data.tireIndustryActivities : []),
    ...(Array.isArray(data.operationalCharacteristics) ? data.operationalCharacteristics : []),
    ...(Array.isArray(data.strategicPriorities) ? data.strategicPriorities : [])
  ]);
}

function getRecommendedKpiIds() {
  const signals = getKpiProfileSignals();
  const recommended = new Set();
  signals.forEach((signal) => {
    (kpiMetricLibrary.recommendationRules[signal] || []).forEach((id) => recommended.add(id));
  });
  return recommended;
}

function getKpiMeasurementInput(kpiIdValue) {
  const data = projectContextIntake?.contextData || {};
  const measurements = data.kpiMeasurements || {};
  return measurements[kpiIdValue] || {};
}

function resolveKpiMeasurementStatus(kpi) {
  const input = getKpiMeasurementInput(kpi.id);
  if (["measured", "estimatable", "missing", "not_applicable"].includes(input.measurement_status)) {
    return input.measurement_status;
  }
  if (input.current_value || input.tracked_where) return "measured";
  if (input.estimate_available || input.estimated_value) return "estimatable";
  return kpi.measurement_status || "missing";
}

function buildKpiGap(kpi, recommended = true) {
  const status = resolveKpiMeasurementStatus(kpi);
  return {
    kpi_id: kpi.id,
    kpi_name: kpi.name,
    recommended,
    measurement_status: status,
    why_it_matters: `${kpi.name} matters because it supports ${kpi.business_objective.toLowerCase()} in ${kpi.business_domain.replace(/_/g, " ")}.`,
    required_data_points: kpi.required_data_points,
    recommended_data_capture_method: `Start capturing ${kpi.required_data_points.slice(0, 3).join(", ")} in the operational workflow or system of record.`,
    related_recommendation: status === "missing" ? `Create a reliable data capture process for ${kpi.name}.` : `Formalize ${kpi.name} ownership and reporting cadence.`,
    roadmap_relevance: kpi.roadmap_relevance
  };
}

function getKpiDashboardModel() {
  const recommendedIds = getRecommendedKpiIds();
  const mandatory = kpiMetricLibrary.seedKpis.filter((kpi, index, source) => kpi.industry === "universal" && source.findIndex((item) => item.id === kpi.id) === index);
  const activityRecommended = kpiMetricLibrary.seedKpis.filter((kpi) => recommendedIds.has(kpi.id));
  const applicable = [...mandatory, ...activityRecommended].filter((kpi, index, source) => source.findIndex((item) => item.id === kpi.id) === index);
  const notApplicable = kpiMetricLibrary.seedKpis.filter((kpi) => kpi.industry === "tire_industry" && !recommendedIds.has(kpi.id));
  const measured = applicable.filter((kpi) => resolveKpiMeasurementStatus(kpi) === "measured");
  const estimatable = applicable.filter((kpi) => resolveKpiMeasurementStatus(kpi) === "estimatable");
  const missing = applicable.filter((kpi) => resolveKpiMeasurementStatus(kpi) === "missing");
  const custom = projectContextIntake?.contextData?.customKpis || [];
  return {
    signals: [...getKpiProfileSignals()],
    mandatory,
    recommended: activityRecommended,
    measured,
    estimatable,
    missing,
    notApplicable,
    custom,
    gaps: missing.map((kpi) => buildKpiGap(kpi, true))
  };
}

function renderKpiItems(kpis, limit = 8) {
  if (!kpis.length) return `<p class="empty-copy">No KPIs in this group yet.</p>`;
  return `
    <div class="kpi-list">
      ${kpis
        .slice(0, limit)
        .map(
          (kpi) => `
            <article>
              <div>
                <strong>${kpi.name}</strong>
                <span>${kpi.business_objective} · ${kpi.business_domain.replace(/_/g, " ")}</span>
              </div>
              <small>${resolveKpiMeasurementStatus(kpi)}</small>
            </article>
          `
        )
        .join("")}
    </div>
    ${kpis.length > limit ? `<span class="kpi-more">+${kpis.length - limit} more</span>` : ""}
  `;
}

function renderKpiMetricLibrary() {
  const container = document.querySelector("#kpi-metric-library-taxonomy");
  if (!container) return;
  const model = getKpiDashboardModel();
  const example = kpiMetricLibrary.seedKpis.find((kpi) => kpi.id === "average_dispatch_time") || kpiMetricLibrary.seedKpis[0];
  const exampleGap = buildKpiGap(example, true);
  const rules = Object.entries(kpiMetricLibrary.recommendationRules);
  container.innerHTML = `
    <div class="taxonomy-summary">
      <strong>${kpiMetricLibrary.name}</strong>
      <span>Defines business vital signs, recommends activity-specific KPIs, classifies measurement status, and turns missing KPI data into assessment findings.</span>
    </div>
    <div class="impact-layout">
      <section class="impact-block">
        <h3>Business Doctor Purpose</h3>
        <div class="output-field-grid">
          ${kpiMetricLibrary.purpose.map((item) => `<span>${item}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Required KPI Object Schema</h3>
        <div class="schema-field-grid">
          ${Object.keys(kpiMetricLibrary.schema).map((field) => `<article><strong>${field}</strong><span>${Array.isArray(kpiMetricLibrary.schema[field]) ? "array" : String(kpiMetricLibrary.schema[field] || "string")}</span></article>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Measurement Status Logic</h3>
        <div class="kpi-status-grid">
          ${Object.entries(kpiMetricLibrary.measurementStatuses)
            .map(([status, definition]) => `<article class="kpi-status-card"><strong>${status}</strong><span>${definition}</span></article>`)
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Business Objectives</h3>
        <div class="output-field-grid">
          ${kpiMetricLibrary.businessObjectives.map((objective) => `<span>${objective}</span>`).join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Current Profile Signals</h3>
        <article class="kpi-profile-card">
          <strong>${model.signals.length ? `${model.signals.length} Layer 1 signals selected` : "No Layer 1 signals selected yet"}</strong>
          <p>${model.signals.length ? model.signals.join(", ").replace(/_/g, " ") : "When Company Context is completed, KPI recommendations are generated from business activities and operational characteristics."}</p>
        </article>
      </section>
      <section class="impact-block">
        <h3>KPI Dashboard Groups</h3>
        <div class="kpi-bucket-grid">
          <article class="kpi-bucket-card measured">
            <div><strong>Measured KPIs</strong><span>${model.measured.length}</span></div>
            ${renderKpiItems(model.measured, 5)}
          </article>
          <article class="kpi-bucket-card estimatable">
            <div><strong>Estimatable KPIs</strong><span>${model.estimatable.length}</span></div>
            ${renderKpiItems(model.estimatable, 5)}
          </article>
          <article class="kpi-bucket-card missing">
            <div><strong>Missing KPIs</strong><span>${model.missing.length}</span></div>
            ${renderKpiItems(model.missing, 6)}
          </article>
          <article class="kpi-bucket-card not-applicable">
            <div><strong>Not Applicable KPIs</strong><span>${model.notApplicable.length}</span></div>
            ${renderKpiItems(model.notApplicable, 5)}
          </article>
        </div>
      </section>
      <section class="impact-block">
        <h3>Mandatory Universal Vital Signs</h3>
        <div class="kpi-seed-grid">
          ${universalKpiGroups
            .map(
              (group) => `
                <article class="kpi-seed-card">
                  <strong>${group.objective}</strong>
                  <span>${group.kpis.length} KPIs</span>
                  <p>${group.kpis.join(", ")}</p>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Tire Industry KPI Library</h3>
        <div class="kpi-seed-grid">
          ${tireKpiGroups
            .map(
              (group) => `
                <article class="kpi-seed-card">
                  <strong>${group.label}</strong>
                  <span>${group.activity}</span>
                  <p>${group.kpis.join(", ")}</p>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Recommendation Rules</h3>
        <div class="kpi-rule-grid">
          ${rules
            .map(
              ([signal, ids]) => `
                <article class="kpi-rule-card">
                  <strong>If Layer 1 includes ${signal}</strong>
                  <span>Recommend ${ids.length} KPIs</span>
                  <p>${ids.map((id) => kpiMetricLibrary.seedKpis.find((kpi) => kpi.id === id)?.name || id).join(", ")}</p>
                </article>
              `
            )
            .join("")}
        </div>
      </section>
      <section class="impact-block">
        <h3>Example KPI Object</h3>
        <article class="kpi-object-card">
          <div>
            <strong>${example.name}</strong>
            <span>${example.business_activity || "universal"} · ${example.roadmap_relevance}</span>
          </div>
          <p>${example.description}</p>
          <div class="schema-field-grid">
            <article><strong>formula</strong><span>${example.formula}</span></article>
            <article><strong>unit</strong><span>${example.unit}</span></article>
            <article><strong>required_data_points</strong><span>${example.required_data_points.join(", ")}</span></article>
            <article><strong>possible_data_sources</strong><span>${example.possible_data_sources.join(", ")}</span></article>
            <article><strong>estimation_questions</strong><span>${example.estimation_questions.slice(0, 3).join(" | ")}</span></article>
            <article><strong>related_problem_types</strong><span>${example.related_problem_types.join(", ")}</span></article>
          </div>
        </article>
      </section>
      <section class="impact-block">
        <h3>KPI Gap Output</h3>
        <article class="kpi-gap-card">
          <strong>${exampleGap.kpi_name}</strong>
          <span>${exampleGap.measurement_status}</span>
          <p>${exampleGap.related_recommendation}</p>
          <div class="tag-list">
            ${exampleGap.required_data_points.map((point) => `<span>${point}</span>`).join("")}
            <span>${exampleGap.roadmap_relevance}</span>
          </div>
        </article>
      </section>
    </div>
  `;
}

function formatQuestionId(prefix, index, start = 1) {
  return `${prefix}-${String(index + start).padStart(3, "0")}`;
}

function renderMasterSurveyArchitecture() {
  document.querySelector("#survey-fields").innerHTML = surveyFields.map((field) => `<span>${field}</span>`).join("");
  document.querySelector("#question-types").innerHTML = questionTypes.map((type) => `<span>${type}</span>`).join("");

  document.querySelector("#master-survey-bank").innerHTML = masterSurveyBank
    .map(
      (stakeholder, stakeholderIndex) => `
        <article class="survey-stakeholder">
          <div class="survey-stakeholder-header">
            <h3>${stakeholder.stakeholder}</h3>
            <span>${stakeholder.categories.reduce((sum, category) => sum + category.questions.length, 0)} questions</span>
          </div>
          ${stakeholder.categories
            .map(
              (category, categoryIndex) => `
                <section class="survey-category">
                  <h4>${category.name}</h4>
                  <div class="question-list">
                    ${category.questions
                      .map(
                        (question, questionIndex) => `
                          <div class="question-row">
                            <div class="question-meta">
                              <strong>${formatQuestionId(category.prefix, questionIndex, category.start || 1)}</strong>
                              <span>${stakeholder.stakeholder}</span>
                              <span>${category.name}</span>
                              <span>Open Text</span>
                              <span>Required: Yes</span>
                              <span>Scoring: No</span>
                              <span>Weight: 1</span>
                            </div>
                            <p><b>EN</b> ${question}</p>
                            <p><b>TR</b> ${masterSurveyTurkishBank[stakeholderIndex][categoryIndex][questionIndex]}</p>
                          </div>
                        `
                      )
                      .join("")}
                  </div>
                </section>
              `
            )
            .join("")}
        </article>
      `
    )
    .join("");
}

function renderListPills(items = []) {
  return `<ul>${items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>`;
}

function renderIntelligenceExplorer() {
  const flow = document.querySelector("#intelligence-flow");
  const detail = document.querySelector("#intelligence-detail");
  if (!flow || !detail) return;
  const copy = getExplorerCopy();
  const activeModule = getActiveExplorerModule(copy);
  document.documentElement.lang = publicExplorerLanguage;
  document.querySelectorAll("[data-public-language]").forEach((button) => {
    button.classList.toggle("active", button.dataset.publicLanguage === publicExplorerLanguage);
  });
  const setText = (selector, value) => {
    const element = document.querySelector(selector);
    if (element) element.textContent = value;
  };
  setText("#explorer-eyebrow", copy.eyebrow);
  setText("#public-hero-eyebrow", copy.heroEyebrow);
  setText("#public-hero-title", copy.heroTitle);
  setText("#public-hero-copy", copy.heroCopy);
  setText("#public-login-link", copy.loginButton);
  setText("#public-proof-one", copy.proofOne);
  setText("#public-proof-two", copy.proofTwo);
  setText("#public-proof-three", copy.proofThree);
  setText("#explorer-title", copy.title);
  setText("#explorer-subtitle", copy.subtitle);
  setText("#explorer-pulse-title", copy.pulseTitle);
  setText("#explorer-pulse-subtitle", copy.pulseSubtitle);
  setText("#explorer-cta-title", copy.ctaTitle);
  setText("#explorer-cta-copy", copy.ctaCopy);
  setText("#public-generate-demo", copy.ctaDemo);
  setText("#public-view-dashboard", copy.ctaDashboard);
  flow.innerHTML = copy.modules
    .map((module, index) => `
      <button class="intelligence-node ${module.id === activeModule.id ? "active" : ""}" data-explorer-module="${module.id}" type="button">
        <small>${String(index + 1).padStart(2, "0")}</small>
        <strong>${escapeHtml(module.title)}</strong>
        <span>${escapeHtml(module.summary)}</span>
      </button>
    `)
    .join("");
  detail.innerHTML = `
    <p class="eyebrow">${String(copy.modules.findIndex((module) => module.id === activeModule.id) + 1).padStart(2, "0")} / ${copy.pulseTitle}</p>
    <h3>${escapeHtml(activeModule.title)}</h3>
    <p>${escapeHtml(activeModule.what)}</p>
    <div class="detail-grid">
      <div class="detail-block"><strong>${escapeHtml(copy.labels.why)}</strong><p>${escapeHtml(activeModule.why)}</p></div>
      <div class="detail-block"><strong>${escapeHtml(copy.labels.inputs)}</strong>${renderListPills(activeModule.inputs)}</div>
      <div class="detail-block"><strong>${escapeHtml(copy.labels.outputs)}</strong>${renderListPills(activeModule.outputs)}</div>
      <div class="detail-block"><strong>${escapeHtml(copy.labels.widgets)}</strong>${renderListPills(activeModule.widgets)}</div>
    </div>
    <div class="detail-example">
      <strong>${escapeHtml(copy.labels.example)}</strong>
      <p>${escapeHtml(activeModule.example)}</p>
    </div>
    <div class="detail-example">
      <strong>${escapeHtml(copy.labels.owner)}</strong>
      <p>${escapeHtml(activeModule.owner)}</p>
    </div>
  `;
}

function focusAuthForPublicCta() {
  const copy = getExplorerCopy();
  showAuthPanel();
  document.querySelector("#auth-subtitle").textContent = copy.signInMessage;
  authMode = "signin";
  document.querySelectorAll("[data-auth-mode]").forEach((item) => item.classList.toggle("active", item.dataset.authMode === "signin"));
  document.querySelectorAll(".signup-only").forEach((item) => item.classList.add("hidden"));
  document.querySelector("#auth-title").textContent = "Welcome back";
  document.querySelector("#auth-submit").textContent = "Sign In";
  document.querySelector("#auth-email")?.focus();
  document.querySelector(".auth-panel")?.scrollIntoView({ behavior: "smooth", block: "center" });
}

function wireEvents() {
  renderIntelligenceExplorer();

  document.addEventListener("click", (event) => {
    const glossaryClose = event.target.closest("[data-glossary-close]");
    if (glossaryClose) {
      glossaryClose.closest(".glossary-panel")?.remove();
      return;
    }
    const glossaryTooltip = event.target.closest("[data-glossary-key]");
    if (glossaryTooltip) {
      event.preventDefault();
      showGlossaryPanel(glossaryTooltip.dataset.glossaryKey);
      return;
    }
    const stateViewButton = event.target.closest("[data-state-view]");
    if (stateViewButton) {
      setActiveView(stateViewButton.dataset.stateView);
      return;
    }
    const stateTargetButton = event.target.closest("[data-state-target]");
    if (stateTargetButton) {
      const target = document.querySelector(`#${CSS.escape(stateTargetButton.dataset.stateTarget)}`);
      target?.scrollIntoView({ behavior: "smooth", block: "center" });
      target?.focus?.();
      return;
    }
    const languageButton = event.target.closest("[data-public-language]");
    if (languageButton) {
      publicExplorerLanguage = languageButton.dataset.publicLanguage === "tr" ? "tr" : "en";
      localStorage.setItem("publicExplorerLanguage", publicExplorerLanguage);
      renderIntelligenceExplorer();
      return;
    }
    const moduleButton = event.target.closest("[data-explorer-module]");
    if (moduleButton) {
      activeExplorerModule = moduleButton.dataset.explorerModule;
      localStorage.setItem("activeExplorerModule", activeExplorerModule);
      renderIntelligenceExplorer();
    }
  });

  document.querySelector("#public-generate-demo")?.addEventListener("click", focusAuthForPublicCta);
  document.querySelector("#public-view-dashboard")?.addEventListener("click", focusAuthForPublicCta);
  document.querySelector("#public-login-link")?.addEventListener("click", focusAuthForPublicCta);

  if (activeResetToken) {
    document.querySelector("#auth-form")?.classList.add("hidden");
    document.querySelector("#forgot-password-button")?.classList.add("hidden");
    document.querySelector("#reset-password-form")?.classList.remove("hidden");
    document.querySelector("#auth-title") && (document.querySelector("#auth-title").textContent = "Reset password");
    document.querySelector("#auth-subtitle") && (document.querySelector("#auth-subtitle").textContent = "Choose a new password for your assessment platform account.");
  }

  document.querySelectorAll("[data-auth-mode]").forEach((button) => {
    button.addEventListener("click", () => {
      authMode = button.dataset.authMode;
      document.querySelectorAll("[data-auth-mode]").forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
      document.querySelectorAll(".signup-only").forEach((item) => item.classList.toggle("hidden", authMode !== "signup"));
      document.querySelector("#auth-title").textContent = authMode === "signup" ? "Create workspace" : "Welcome back";
      document.querySelector("#auth-subtitle").textContent =
        authMode === "signup"
          ? "Set up access for the transformation assessment team."
          : "Access the assessment command center.";
      document.querySelector("#auth-submit").textContent = authMode === "signup" ? "Create Account" : "Sign In";
    });
  });

  document.querySelector("#forgot-password-button")?.addEventListener("click", () => {
    document.querySelector("#auth-form").classList.add("hidden");
    document.querySelector("#forgot-password-button").classList.add("hidden");
    document.querySelector("#forgot-password-form").classList.remove("hidden");
    document.querySelector("#auth-title").textContent = "Reset access";
    document.querySelector("#auth-subtitle").textContent = "Enter your email and we will send a secure reset link.";
    document.querySelector("#forgot-password-email").value = document.querySelector("#auth-email").value;
  });

  document.querySelector("#back-to-login-from-forgot")?.addEventListener("click", () => {
    document.querySelector("#forgot-password-form").classList.add("hidden");
    document.querySelector("#auth-form").classList.remove("hidden");
    document.querySelector("#forgot-password-button").classList.remove("hidden");
    document.querySelector("#auth-title").textContent = "Welcome back";
    document.querySelector("#auth-subtitle").textContent = "Access the assessment command center.";
  });

  document.querySelector("#forgot-password-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const email = normalizeEmail(document.querySelector("#forgot-password-email").value);
    try {
      await apiRequest("/api/auth/request-password-reset", {
        method: "POST",
        body: JSON.stringify({ email })
      });
      document.querySelector("#auth-subtitle").textContent = "If this email exists, a reset link has been sent.";
    } catch (error) {
      document.querySelector("#auth-subtitle").textContent = error.message || "Password reset failed.";
    }
  });

  document.querySelector("#reset-password-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const password = document.querySelector("#reset-password-input").value;
    const confirm = document.querySelector("#reset-password-confirm").value;
    if (password !== confirm) {
      document.querySelector("#auth-subtitle") && (document.querySelector("#auth-subtitle").textContent = "Passwords do not match. Please try again.");
      return;
    }
    if (password.length < 8) {
      document.querySelector("#auth-subtitle") && (document.querySelector("#auth-subtitle").textContent = "Password must be at least 8 characters.");
      return;
    }
    try {
      await apiRequest("/api/auth/reset-password", {
        method: "POST",
        body: JSON.stringify({ token: activeResetToken, password })
      });
      activeResetToken = "";
      history.replaceState({}, "", location.pathname);
      // Revoke the old in-memory session so "Open Dashboard" disappears
      // and the user can't accidentally open the app with the now-revoked token.
      clearSession();
      currentUserEmail = "";
      currentUser = null;
      showPublicHomepageForSavedSession();
      document.querySelector("#reset-password-form")?.classList.add("hidden");
      document.querySelector("#auth-form")?.classList.remove("hidden");
      document.querySelector("#forgot-password-button")?.classList.remove("hidden");
      document.querySelector("#auth-title") && (document.querySelector("#auth-title").textContent = "Welcome back");
      document.querySelector("#auth-subtitle") && (document.querySelector("#auth-subtitle").textContent = "Password reset. Sign in with your new password.");
    } catch (error) {
      document.querySelector("#auth-subtitle").textContent = error.message || "Password reset failed.";
    }
  });

  document.querySelector("#back-to-login-from-reset")?.addEventListener("click", () => {
    activeResetToken = "";
    history.replaceState({}, "", location.pathname);
    clearSession();
    currentUserEmail = "";
    currentUser = null;
    document.querySelector("#reset-password-form")?.classList.add("hidden");
    document.querySelector("#auth-form")?.classList.remove("hidden");
    document.querySelector("#forgot-password-button")?.classList.remove("hidden");
    document.querySelector("#auth-title") && (document.querySelector("#auth-title").textContent = "Welcome back");
    document.querySelector("#auth-subtitle") && (document.querySelector("#auth-subtitle").textContent = "Access the assessment command center.");
    showPublicHomepageForSavedSession();
  });

  let _pendingTotpToken = null;

  document.querySelector("#auth-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const email = normalizeEmail(document.querySelector("#auth-email").value);
    const password = document.querySelector("#auth-password").value;
    if (authMode === "signup") {
      document.querySelector("#auth-subtitle").textContent = "Sign-up is creator-managed so nobody can assign themselves a role. Contact the platform creator to receive credentials.";
      return;
    }
    const submitBtn = document.querySelector("#auth-submit");
    if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = "Signing in…"; }
    try {
      const payload = await apiRequest("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({ email, password })
      });
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = "Sign In"; }
      if (payload.twoFactorSetupRequired) {
        // Admin account without 2FA — forced enrollment before session is granted
        _pendingTotpToken = payload.pendingToken;
        document.querySelector("#login-section").classList.add("hidden");
        document.querySelector("#totp-setup-section").classList.remove("hidden");
        document.querySelector("#totp-setup-code").value = "";
        document.querySelector("#totp-setup-subtitle").textContent =
          "Hesabınız iki faktörlü doğrulama gerektiriyor. QR kodu tarayın, ardından 6 haneli kodu girin.";
        // Render QR code locally — secret never sent to any external service
        _renderQRCode(document.getElementById("totp-setup-qr"), payload.otpauthUrl);
        document.getElementById("totp-setup-manual-key").textContent = payload.secret;
        document.querySelector("#totp-setup-code").focus();
        return;
      }
      if (payload.twoFactorRequired) {
        _pendingTotpToken = payload.pendingToken;
        document.querySelector("#login-section").classList.add("hidden");
        document.querySelector("#totp-section").classList.remove("hidden");
        document.querySelector("#totp-code").value = "";
        document.querySelector("#totp-subtitle").textContent = "Kimlik doğrulama uygulamanızdaki 6 haneli kodu girin.";
        document.querySelector("#totp-code").focus();
        return;
      }
      currentUser = payload.user;
      currentSessionToken = payload.sessionToken || "";
      currentRole = normalizeAppRole(payload.user?.role || "participant");
      currentUserEmail = email;
      storePlatformUser(payload.user);
      localStorage.setItem("currentPlatformUser", JSON.stringify(currentUser));
      saveSession(email, currentSessionToken);
      openAuthenticatedApp();
    } catch (error) {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = "Sign In"; }
      document.querySelector("#auth-subtitle").textContent = error.message || "Sign in failed.";
      return;
    }
  });

  document.querySelector("#totp-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const code = document.querySelector("#totp-code").value.trim();
    document.querySelector("#totp-subtitle").textContent = "Doğrulanıyor…";
    try {
      const payload = await apiRequest("/api/auth/2fa/confirm", {
        method: "POST",
        body: JSON.stringify({ pendingToken: _pendingTotpToken, code })
      });
      _pendingTotpToken = null;
      currentUser = payload.user;
      currentSessionToken = payload.sessionToken || "";
      currentRole = normalizeAppRole(payload.user?.role || "participant");
      currentUserEmail = payload.user?.email || "";
      storePlatformUser(payload.user);
      localStorage.setItem("currentPlatformUser", JSON.stringify(currentUser));
      saveSession(currentUserEmail, currentSessionToken);
      document.querySelector("#totp-section").classList.add("hidden");
      openAuthenticatedApp();
    } catch (error) {
      document.querySelector("#totp-subtitle").textContent = error.message || "Doğrulama başarısız.";
      document.querySelector("#totp-code").value = "";
      document.querySelector("#totp-code").focus();
    }
  });

  document.querySelector("#back-to-login-from-totp")?.addEventListener("click", () => {
    _pendingTotpToken = null;
    document.querySelector("#totp-section").classList.add("hidden");
    document.querySelector("#login-section").classList.remove("hidden");
  });

  // ── Mandatory 2FA enrollment form ────────────────────────────────────────
  document.querySelector("#totp-setup-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const code = document.querySelector("#totp-setup-code").value.trim();
    const btn = document.querySelector("#totp-setup-submit");
    if (btn) { btn.disabled = true; btn.textContent = "Etkinleştiriliyor…"; }
    document.querySelector("#totp-setup-subtitle").textContent = "Doğrulanıyor…";
    try {
      const payload = await apiRequest("/api/auth/2fa/complete-setup", {
        method: "POST",
        body: JSON.stringify({ pendingToken: _pendingTotpToken, code })
      });
      _pendingTotpToken = null;
      currentUser = payload.user;
      currentSessionToken = payload.sessionToken || "";
      currentRole = normalizeAppRole(payload.user?.role || "participant");
      currentUserEmail = payload.user?.email || "";
      storePlatformUser(payload.user);
      localStorage.setItem("currentPlatformUser", JSON.stringify(currentUser));
      saveSession(currentUserEmail, currentSessionToken);
      document.querySelector("#totp-setup-section").classList.add("hidden");
      openAuthenticatedApp();
    } catch (error) {
      if (btn) { btn.disabled = false; btn.textContent = "Etkinleştir ve Giriş Yap"; }
      document.querySelector("#totp-setup-subtitle").textContent = error.message || "Doğrulama başarısız.";
      document.querySelector("#totp-setup-code").value = "";
      document.querySelector("#totp-setup-code").focus();
    }
  });

  document.querySelector("#back-to-login-from-totp-setup")?.addEventListener("click", () => {
    _pendingTotpToken = null;
    document.querySelector("#totp-setup-section").classList.add("hidden");
    document.querySelector("#totp-setup-qr").innerHTML = "";
    document.getElementById("totp-setup-manual-key").textContent = "";
    document.querySelector("#login-section").classList.remove("hidden");
  });

  // ── Security settings modal (2FA) ────────────────────────────────────────

  // Render a QR code into `container` without sending data to any external service.
  // Uses the tiny qrcodejs library loaded on demand from cdnjs (already in CSP allowlist).
  function _renderQRCode(container, text) {
    container.innerHTML = "";
    function doRender() {
      try {
        new window.QRCode(container, { text, width: 200, height: 200, colorDark: "#000", colorLight: "#fff" });
      } catch (e) {
        container.innerHTML = `<p style="color:#f44;font-size:.8rem">QR oluşturulamadı. Lütfen kodu manuel girin.</p>`;
      }
    }
    if (window.QRCode) { doRender(); return; }
    const s = document.createElement("script");
    s.src = "https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js";
    s.onload = doRender;
    s.onerror = () => { container.innerHTML = `<p style="color:#f44;font-size:.8rem">QR yüklenemedi. Kodu manuel girin.</p>`; };
    document.head.appendChild(s);
  }

  async function renderSecurityModal() {
    const content = document.querySelector("#security-modal-content");
    content.innerHTML = "<p style='color:#888;font-size:.875rem'>Yükleniyor…</p>";
    try {
      const { enabled } = await apiRequest("/api/auth/2fa/status");
      if (enabled) {
        content.innerHTML = `
          <p style="margin:0 0 1rem;font-size:.9rem">2FA <strong style="color:#4caf50">aktif</strong>. Oturum açarken kimlik doğrulama uygulamanızdan kod gerekiyor.</p>
          <form id="disable-2fa-form">
            <label style="display:block;margin-bottom:.75rem;font-size:.875rem">Devre dışı bırakmak için şifrenizi girin
              <input type="password" id="disable-2fa-password" placeholder="Şifreniz" required
                style="display:block;width:100%;margin-top:.4rem;padding:.6rem;border-radius:6px;border:1px solid #333;background:#111;color:#eee;font-size:.9rem"/>
            </label>
            <button class="primary-button" type="submit" style="width:100%">2FA Devre Dışı Bırak</button>
            <p id="disable-2fa-error" style="color:#f44;font-size:.8rem;margin:.5rem 0 0"></p>
          </form>`;
        document.querySelector("#disable-2fa-form").addEventListener("submit", async (e) => {
          e.preventDefault();
          const password = document.querySelector("#disable-2fa-password").value;
          try {
            await apiRequest("/api/auth/2fa/disable", { method: "POST", body: JSON.stringify({ password }) });
            renderSecurityModal();
          } catch (err) {
            document.querySelector("#disable-2fa-error").textContent = err.message || "Hata.";
          }
        });
      } else {
        // Setup flow: fetch secret
        const { secret, otpauthUrl } = await apiRequest("/api/auth/2fa/setup");
        // QR generated entirely in-browser — secret NEVER sent to any third-party service
        content.innerHTML = `
          <p style="font-size:.875rem;margin:0 0 1rem">Google Authenticator, Authy veya benzeri bir uygulama ile QR kodu tarayın veya anahtarı manuel girin.</p>
          <div id="qr-canvas-container" style="text-align:center;margin-bottom:1rem;min-height:200px"></div>
          <p style="font-size:.8rem;color:#888;word-break:break-all;margin:0 0 1rem;text-align:center;background:#111;padding:.5rem;border-radius:6px">${secret}</p>
          <form id="enable-2fa-form">
            <label style="display:block;margin-bottom:.75rem;font-size:.875rem">Uygulamadaki 6 haneli kodu girerek etkinleştirin
              <input type="text" id="enable-2fa-code" inputmode="numeric" pattern="\\d{6}" maxlength="6" placeholder="000000" required autocomplete="off"
                style="display:block;width:100%;margin-top:.4rem;padding:.6rem;border-radius:6px;border:1px solid #333;background:#111;color:#eee;font-size:1.2rem;letter-spacing:.3rem;text-align:center"/>
            </label>
            <button class="primary-button" type="submit" style="width:100%">2FA Etkinleştir</button>
            <p id="enable-2fa-error" style="color:#f44;font-size:.8rem;margin:.5rem 0 0"></p>
          </form>`;
        // Render QR locally — no secret leaves the browser
        _renderQRCode(document.getElementById("qr-canvas-container"), otpauthUrl);
        document.querySelector("#enable-2fa-form").addEventListener("submit", async (e) => {
          e.preventDefault();
          const code = document.querySelector("#enable-2fa-code").value.trim();
          try {
            await apiRequest("/api/auth/2fa/enable", { method: "POST", body: JSON.stringify({ secret, code }) });
            renderSecurityModal();
          } catch (err) {
            document.querySelector("#enable-2fa-error").textContent = err.message || "Hata.";
          }
        });
      }
    } catch {
      content.innerHTML = "<p style='color:#f44'>Yüklenemedi.</p>";
    }
  }

  document.querySelector("#open-security-settings")?.addEventListener("click", () => {
    document.querySelector("#security-modal-backdrop").classList.remove("hidden");
    renderSecurityModal();
  });
  document.querySelector("#security-modal-close")?.addEventListener("click", () => {
    document.querySelector("#security-modal-backdrop").classList.add("hidden");
  });
  document.querySelector("#security-modal-backdrop")?.addEventListener("click", (e) => {
    if (e.target === e.currentTarget) document.querySelector("#security-modal-backdrop").classList.add("hidden");
  });

  document.querySelector("#open-dashboard-button")?.addEventListener("click", openAuthenticatedApp);

  document.querySelectorAll(".nav-item").forEach((button) => {
    button.addEventListener("click", () => {
      if (button.dataset.managerSection) activeManagerSection = button.dataset.managerSection;
      if (button.dataset.assessmentTab) {
        activeAssessmentWorkspaceTab = button.dataset.assessmentTab;
        localStorage.setItem("activeAssessmentWorkspaceTab", activeAssessmentWorkspaceTab);
      }
      setActiveView(button.dataset.view);
      document.querySelectorAll(".nav-item").forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
      if (button.dataset.managerSection && normalizeAppRole(currentRole) === "assessment_manager") {
        requestAnimationFrame(() => {
          document.querySelector(`#${CSS.escape(button.dataset.managerSection)}`)?.scrollIntoView({ behavior: "smooth", block: "start" });
        });
      }
      if (button.dataset.view === "executive-report" && !executiveReportState) {
        refreshExecutiveReport();
      }
      if (button.dataset.view === "operations-center") {
        refreshKrbOperationsCenter();
      }
    });
  });

  document.addEventListener("click", async (event) => {
    if (event.target.closest("[data-view-executive-report]")) {
      setActiveView("executive-report");
      await refreshExecutiveReport();
      return;
    }
    const inlineViewButton = event.target.closest("button[data-view]:not(.nav-item)");
    if (inlineViewButton) {
      if (inlineViewButton.dataset.managerSection) activeManagerSection = inlineViewButton.dataset.managerSection;
      if (inlineViewButton.dataset.assessmentTab) {
        activeAssessmentWorkspaceTab = inlineViewButton.dataset.assessmentTab;
        localStorage.setItem("activeAssessmentWorkspaceTab", activeAssessmentWorkspaceTab);
      }
      setActiveView(inlineViewButton.dataset.view);
      if (inlineViewButton.dataset.managerSection && normalizeAppRole(currentRole) === "assessment_manager") {
        requestAnimationFrame(() => {
          document.querySelector(`#${CSS.escape(inlineViewButton.dataset.managerSection)}`)?.scrollIntoView({ behavior: "smooth", block: "start" });
        });
      }
      if (inlineViewButton.dataset.view === "executive-report") await refreshExecutiveReport();
      if (inlineViewButton.dataset.view === "operations-center") await refreshKrbOperationsCenter();
      return;
    }
    if (event.target.closest("#generate-executive-report, #empty-generate-executive-report")) {
      await refreshExecutiveReport();
      return;
    }
    if (event.target.closest("#refresh-operations-center")) {
      await refreshKrbOperationsCenter();
      return;
    }
    if (event.target.closest("#refresh-platform-command-center")) {
      try {
        platformCommandCenterState = await apiRequest("/api/platform-command-center");
        platformCommandCenterError = "";
      } catch (error) {
        platformCommandCenterState = null;
        platformCommandCenterError = error.message;
      }
      renderPlatformCommandCenter();
      return;
    }
    const platformClassificationButton = event.target.closest("[data-platform-classification-filter]");
    if (platformClassificationButton) {
      platformClassificationFilter = platformClassificationButton.dataset.platformClassificationFilter || "production";
      localStorage.setItem("platformClassificationFilter", platformClassificationFilter);
      renderPlatformCommandCenter();
      return;
    }
    const managerJumpButton = event.target.closest(".manager-jump-action");
    if (managerJumpButton) {
      const target = managerJumpButton.dataset.managerJump || "manager-overview";
      const targetElement = document.querySelector(`#${CSS.escape(target)}`);
      targetElement?.scrollIntoView({ behavior: "smooth", block: "start" });
      targetElement?.focus?.();
      return;
    }
    const opsSectionButton = event.target.closest("[data-ops-section]");
    if (opsSectionButton) {
      krbOperationsSection = opsSectionButton.dataset.opsSection;
      localStorage.setItem("krbOperationsSection", krbOperationsSection);
      renderKrbOperationsCenter();
      return;
    }
    const opsViewButton = event.target.closest(".ops-open-view");
    if (opsViewButton) {
      setActiveView(opsViewButton.dataset.opsView || "dashboard");
      if (opsViewButton.dataset.opsView === "executive-report") await refreshExecutiveReport();
      return;
    }
    const generatedIssueButton = event.target.closest(".create-generated-issue");
    if (generatedIssueButton) {
      const issue = krbOperationsState?.generated_issues?.[Number(generatedIssueButton.dataset.generatedIndex)];
      if (issue) {
        await apiRequest("/api/operations-center/issues", { method: "POST", body: JSON.stringify(issue) });
        await refreshKrbOperationsCenter();
      }
      return;
    }
    const resolveIssueButton = event.target.closest(".resolve-krb-issue");
    if (resolveIssueButton) {
      if (!window.confirm("Resolve this issue?")) return;
      await apiRequest(`/api/operations-center/issues/${encodeURIComponent(resolveIssueButton.dataset.issueId)}`, {
        method: "PATCH",
        body: JSON.stringify({ status: "resolved", resolution_notes: "Resolved from Operations Center." })
      });
      await refreshKrbOperationsCenter();
      return;
    }
  });

  document.addEventListener("change", async (event) => {
    if (event.target?.id === "report-include-drafts") {
      await refreshExecutiveReport();
      return;
    }
    if (event.target?.id === "report-show-evidence" || event.target?.id === "report-show-appendix") {
      refreshOwnerSurfaceFromStore();
      refreshConsultantSurfaceFromStore();
      refreshPlatformSurfaceFromStore();
    }
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-question-bank-role]");
    if (!button) return;
    activeQuestionBankRole = button.dataset.questionBankRole;
    refreshPlatformSurfaceFromStore();
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-open-project]");
    if (!button) return;
    const project = assessmentProjects.find((item) => String(item.id) === String(button.dataset.openProject)) || {
      id: "local-krb",
      clientDisplayName: "KRB",
      name: "Digital Transformation Assessment",
      organizationName: "KRB",
      defaultLanguage: "tr",
      status: "active"
    };
    openProjectWorkspace(project);
    surveyInvites = [];
    responses = [];
    projectParticipants = [];
    projectContextIntake = null;
    saveProjectContextIntake();
    renderProjects();
    setActiveView("dashboard");
    loadDatabaseState();
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-platform-open-project]");
    if (!button) return;
    const project = assessmentProjects.find((item) => String(item.id) === String(button.dataset.platformOpenProject));
    if (!project) return;
    openProjectWorkspace(project);
    surveyInvites = [];
    responses = [];
    projectParticipants = [];
    projectContextIntake = null;
    saveProjectContextIntake();
    setActiveView(button.dataset.platformView || "dashboard");
    loadDatabaseState();
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-consultant-open-project]");
    if (!button) return;
    const project = assessmentProjects.find((item) => String(item.id) === String(button.dataset.consultantOpenProject));
    if (!project) return;
    openProjectWorkspace(project);
    surveyInvites = [];
    responses = [];
    projectParticipants = [];
    projectContextIntake = null;
    saveProjectContextIntake();
    setActiveView(button.dataset.consultantView || "dashboard");
    loadDatabaseState();
  });

  document.querySelector("#open-context-intake")?.addEventListener("click", () => {
    setActiveView("context");
  });

  document.querySelector("#refresh-findings-workbench")?.addEventListener("click", refreshAssessmentEngine);

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-context-language]");
    if (!button) return;
    saveActiveContextLanguage(button.dataset.contextLanguage);
    const languageInput = document.querySelector("#context-language");
    if (languageInput) languageInput.value = activeContextLanguage;
    renderProjectContextForm();
    renderContextSummary();
  });

  document.addEventListener("click", async (event) => {
    const ownerFindingButton = event.target.closest("[data-owner-select-finding]");
    if (ownerFindingButton) {
      selectedFindingId = ownerFindingButton.dataset.ownerSelectFinding;
      localStorage.setItem("selectedFindingId", selectedFindingId);
      document.querySelector("#owner-evidence-drawer")?.scrollIntoView({ behavior: "smooth", block: "start" });
      return;
    }

    const heatmapCellButton = event.target.closest("[data-owner-heatmap-cell]");
    if (heatmapCellButton) {
      selectedHeatmapCellKey = heatmapCellButton.dataset.ownerHeatmapCell;
      localStorage.setItem("selectedHeatmapCellKey", selectedHeatmapCellKey);
      return;
    }

    const selectButton = event.target.closest("[data-select-finding]");
    if (selectButton) {
      selectedFindingId = selectButton.dataset.selectFinding;
      localStorage.setItem("selectedFindingId", selectedFindingId);
      return;
    }

  });

  document.querySelector("#context-language")?.addEventListener("change", (event) => {
    saveActiveContextLanguage(event.target.value);
    renderProjectContextForm();
    renderContextSummary();
  });

  document.addEventListener("change", (event) => {
    if (event.target.name !== "context_industry") return;
    projectContextIntake = {
      ...(projectContextIntake || {}),
      language: getContextLanguage(),
      contextData: {
        ...(projectContextIntake?.contextData || {}),
        industry: event.target.value
      }
    };
    saveProjectContextIntake();
    renderProjectContextForm();
    renderContextSummary();
  });

  document.addEventListener("change", (event) => {
    if (event.target.name !== "stakeholder_role") return;
    const selectedIds = new Set(
      Array.from(document.querySelectorAll('[name="stakeholder_role"]:checked')).map((input) => input.value)
    );
    persistSelectedStakeholderRoles(selectedIds);
    syncProjectContextSelection();
  });

  document.addEventListener("change", (event) => {
    if (event.target.name !== "business_domain") return;
    const selectedIds = new Set(
      Array.from(document.querySelectorAll('[name="business_domain"]:checked')).map((input) => input.value)
    );
    persistSelectedBusinessDomains(selectedIds);
    syncProjectContextSelection();
    renderBusinessDomainsTaxonomy();
  });

  document.addEventListener("change", (event) => {
    if (event.target.name !== "assessment_category") return;
    const selectedIds = new Set(
      Array.from(document.querySelectorAll('[name="assessment_category"]:checked')).map((input) => input.value)
    );
    persistSelectedAssessmentCategories(selectedIds);
    syncProjectContextSelection();
    renderAssessmentCategoriesTaxonomy();
  });

  document.addEventListener("change", (event) => {
    if (event.target.name !== "problem_type") return;
    const selectedIds = new Set(
      Array.from(document.querySelectorAll('[name="problem_type"]:checked')).map((input) => input.value)
    );
    persistSelectedProblemTypes(selectedIds);
    syncProjectContextSelection();
    renderProblemTypesTaxonomy();
  });

  document.querySelector("#project-context-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      await saveProjectContext({ publicSubmit: Boolean(activeContextToken) });
    } catch (error) {
      document.querySelector("#context-form-output").innerHTML = `<strong>Context save failed</strong><p>${error.message}</p>`;
    }
  });

  document.querySelector("#context-share-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      await createContextShareLink();
    } catch (error) {
      document.querySelector("#context-share-output").innerHTML = `<strong>${error.authExpired ? "Sign in required" : "Share link failed"}</strong><p>${error.message}</p>`;
    }
  });

  document.querySelector("#send-context-email")?.addEventListener("click", async () => {
    try {
      await createContextShareLink({ sendEmail: true });
    } catch (error) {
      document.querySelector("#context-share-output").innerHTML = `<strong>${error.authExpired ? "Sign in required" : "Email failed"}</strong><p>${error.message}</p>`;
    }
  });

  document.querySelector("#project-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const companyName = document.querySelector("#project-company-name").value.trim();
    const domain = document.querySelector("#project-domain").value.trim();
    const industry = document.querySelector("#project-industry").value.trim();
    const defaultLanguage = document.querySelector("#project-language").value;
    const output = document.querySelector("#project-create-output");
    output.innerHTML = "<strong>Creating project...</strong><p>Preparing a reusable assessment workspace.</p>";
    try {
      const payload = await apiRequest("/api/projects", {
        method: "POST",
        body: JSON.stringify({
          organizationName: companyName || domain,
          domain,
          industry,
          industryContext: industry || (domain ? `Initial company understanding starts from ${domain}.` : ""),
          defaultLanguage,
          name: "Digital Transformation Assessment"
        })
      });
      if (payload.project) {
        assessmentProjects.unshift(payload.project);
        saveProjects();
        saveActiveProject(payload.project);
        renderProjects();
      output.innerHTML = `<strong>Organization created</strong><p>${payload.project.clientDisplayName} is ready. Open the workspace to configure assessment setup and collection.</p>`;
      }
    } catch (error) {
      output.innerHTML = `<strong>Organization creation failed</strong><p>${error.message}</p>`;
    }
  });

  document.querySelector("#stakeholder-select")?.addEventListener("change", (event) => {
    syncLanguageSelectForStakeholder(document.querySelector("#survey-language-input"), event.target.value);
    syncLanguageSelectForStakeholder(document.querySelector("#composer-language"), event.target.value);
    renderSurveyForm(event.target.value);
    const composerStakeholder = document.querySelector("#composer-stakeholder");
    if (composerStakeholder) composerStakeholder.value = event.target.value;
  });

  document.querySelector("#composer-stakeholder")?.addEventListener("change", (event) => {
    const stakeholderSelect = document.querySelector("#stakeholder-select");
    if (stakeholderSelect) stakeholderSelect.value = event.target.value;
    syncLanguageSelectForStakeholder(document.querySelector("#composer-language"), event.target.value);
    syncLanguageSelectForStakeholder(document.querySelector("#survey-language-input"), event.target.value);
    renderSurveyForm(event.target.value);
  });

  document.querySelector("#composer-form")?.addEventListener("submit", (event) => {
    event.preventDefault();
    const context = {
      stakeholderId: document.querySelector("#composer-stakeholder").value,
      language: document.querySelector("#composer-language").value,
      industry: document.querySelector("#composer-industry").value || activeProject?.industryContext || "",
      depth: document.querySelector("#composer-depth").value,
      problems: document.querySelector("#composer-problems").value
    };
    composerState.questions = generateRecommendedQuestions(context);
    renderComposerResults();
  });

  document.addEventListener("click", (event) => {
    const toggleButton = event.target.closest("[data-toggle-composer-question]");
    if (toggleButton) {
      const question = composerState.questions.find((item) => item.id === toggleButton.dataset.toggleComposerQuestion);
      if (question) {
        question.kept = !question.kept;
        renderComposerResults();
      }
    }

    if (event.target.closest("[data-reset-composer]")) {
      composerState.questions.forEach((question) => {
        question.kept = true;
      });
      renderComposerResults();
    }

    if (event.target.closest("[data-apply-composer]")) {
      renderComposedSurveyPreview();
      document.querySelector("#share-box").innerHTML = "<strong>Composed survey applied</strong><p>The preview now uses the recommended question set.</p>";
    }
  });

  document.querySelector("#download-participant-template")?.addEventListener("click", async () => {
    try {
      await downloadParticipantTemplate();
    } catch (error) {
      document.querySelector("#participant-upload-output").innerHTML = `<strong>Template download failed</strong><p>${error.message}</p>`;
    }
  });

  document.querySelector("#participant-excel-input")?.addEventListener("change", async (event) => {
    try {
      await importParticipantExcel(event.target.files?.[0]);
      event.target.value = "";
    } catch (error) {
      document.querySelector("#participant-upload-output").innerHTML = `<strong>Participant import failed</strong><p>${error.message}</p>`;
    }
  });

  document.querySelector("#participant-select")?.addEventListener("change", (event) => {
    const participant = projectParticipants.find((item) => item.id === event.target.value);
    if (!participant) return;
    document.querySelector("#stakeholder-select").value = participant.stakeholder || "owner";
    document.querySelector("#composer-stakeholder").value = participant.stakeholder || "owner";
    const participantLanguage = resolveSurveyLanguageForStakeholder(participant.stakeholder, participant.language || "tr");
    syncLanguageSelectForStakeholder(document.querySelector("#survey-language-input"), participant.stakeholder, participantLanguage);
    syncLanguageSelectForStakeholder(document.querySelector("#composer-language"), participant.stakeholder, participantLanguage);
    document.querySelector("#recipient-input").value = participant.name || "";
    document.querySelector("#recipient-email-input").value = participant.email || "";
    document.querySelector("#department-input").value = participant.department || participant.company || "";
    renderSurveyForm(participant.stakeholder);
  });

  document.querySelector("#link-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const stakeholder = document.querySelector("#stakeholder-select").value;
    const template = templates.find((item) => item.id === stakeholder) || templates[0];
    const department = document.querySelector("#department-input").value || "General";
    const recipient = document.querySelector("#recipient-input").value || "Participant";
    const email = document.querySelector("#recipient-email-input").value || "";
    const language = resolveSurveyLanguageForStakeholder(stakeholder, document.querySelector("#survey-language-input").value || "tr");
    syncLanguageSelectForStakeholder(document.querySelector("#survey-language-input"), stakeholder, language);
    const token = `${stakeholder}-${encodeURIComponent(department)}-${encodeURIComponent(recipient)}-${Math.random().toString(16).slice(2, 8)}`;
    const url = `${location.origin}${location.pathname}?survey=${token}&type=${stakeholder}&lang=${language}`;
    const copy = getTemplateCopy(template, language);
    const invite = {
      token,
      templateId: stakeholder,
      stakeholderName: copy.name,
      department,
      recipient,
      email,
      language,
      url,
      status: "Created",
      createdAt: new Date().toISOString(),
      respondedAt: null
    };
    surveyInvites.unshift(invite);
    saveSurveyInvites();
    await persistSurveyAssignment(invite);

    const fallbackEmail = buildSurveyEmail(invite);
    const mailSubject = encodeURIComponent(fallbackEmail.subject);
    const mailBody = encodeURIComponent(fallbackEmail.body);
    const mailto = email ? `mailto:${email}?subject=${mailSubject}&body=${mailBody}` : `mailto:?subject=${mailSubject}&body=${mailBody}`;
    document.querySelector("#share-box").innerHTML = `
      <strong>Private survey link created</strong>
      <p>${url}</p>
      <div class="meeting-actions">
        <a class="ghost-link" href="${url}">Open Survey</a>
        <button class="primary-button" data-send-outlook="${token}" type="button">Send Email</button>
        <a class="ghost-link" href="${mailto}">Open Email Draft</a>
      </div>
    `;
  });

  document.querySelector("#survey-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const template = templates.find((item) => item.id === data.get("template")) || templates[0];
    const token = data.get("token");
    const invite = surveyInvites.find((item) => item.token === token);
    const language = data.get("language") || invite?.language || "en";
    const copy = getTemplateCopy(template, language);
    const structuredQuestions = getStructuredQuestionBank(template.id);
    const responseQuestions = structuredQuestions.length ? structuredQuestions.map((question) => question.question_text) : copy.questions;
    const responseRecord = {
      stakeholder: copy.name,
      templateId: template.id,
      recipient: data.get("recipient"),
      department: data.get("department"),
      process: data.get("process"),
      pain: structuredQuestions.length ? getStructuredQuestionAnswer(data, 0, structuredQuestions[0].response_type) : data.get("q0"),
      impact: data.get("impact"),
      urgency: data.get("urgency"),
      language,
      questionBankVersion: structuredQuestions.length ? getQuestionBankVersion(template.id) : null,
      answers: responseQuestions.map((question, index) => ({
        question,
        questionId: structuredQuestions[index]?.question_id || null,
        responseType: structuredQuestions[index]?.response_type || "open_text",
        metadata: structuredQuestions[index] || null,
        answer: structuredQuestions.length ? getStructuredQuestionAnswer(data, index, structuredQuestions[index].response_type) : data.get(`q${index}`)
      })),
      sourceToken: token || null,
      submittedAt: new Date().toISOString()
    };
    responses.unshift(responseRecord);
    if (invite) {
      invite.status = "Completed";
      invite.respondedAt = new Date().toISOString();
      saveSurveyInvites();
      activeSurveyToken = null;
      history.replaceState({}, "", location.pathname);
    }
    saveResponses();
    try {
      await persistSurveyResponse(responseRecord);
      await refreshAssessmentEngine();
    } catch (error) {
      document.querySelector("#share-box").innerHTML = `<strong>Database sync warning</strong><p>${error.message}</p>`;
    }
    // Legacy survey submit — broad legacy refresh removed.
    // This handler will be deleted with legacy
    // survey cleanup pass.
    // No replacement needed — legacy path only.
    renderSurveySuccess(language);
    document.querySelector("#share-box").innerHTML = "<strong>Survey response saved</strong><p>The response is now included in dashboards and AI analysis.</p>";
  });

  document.querySelector("#export-report")?.addEventListener("click", exportReport);
  document.querySelector("#generate-demo-assessment")?.addEventListener("click", async () => {
    const container = document.querySelector("#assessment-engine-dashboard");
    try {
      if (container) {
        container.innerHTML = "<article class=\"engine-empty\"><strong>Generating demo assessment...</strong><p>Creating Organization Profile, stakeholder sessions, responses, findings, evidence, recommendations, roadmap items, and approved executive dashboard outputs.</p></article>";
      }
      const payload = await apiRequest("/api/demo/krb-phase-1", { method: "POST" });
      if (payload.project) {
        openProjectWorkspace(payload.project);
      }
      assessmentEngineState = payload.dashboard || null;
      await loadDatabaseState();
      setActiveView("executive-preview");
    } catch (error) {
      if (container) container.innerHTML = `<article class="engine-empty"><strong>Demo generation failed</strong><p>${error.message}</p></article>`;
    }
  });

  document.querySelector("#delete-demo-assessment")?.addEventListener("click", async () => {
    const container = document.querySelector("#assessment-engine-dashboard");
    try {
      if (container) container.innerHTML = "<article class=\"engine-empty\"><strong>Deleting demo assessment...</strong><p>Removing demo workspace, sessions, responses, findings, evidence, recommendations, and roadmap items.</p></article>";
      const wasDemoOpen = ["Tenant Demo: KRB", "KRB Phase 1 Demo"].includes(activeProject?.clientDisplayName)
        || ["Tenant Demo: KRB", "KRB Phase 1 Demo"].includes(activeProject?.name);
      await apiRequest("/api/demo/krb-phase-1", { method: "DELETE" });
      if (wasDemoOpen) clearActiveWorkspace();
      await loadDatabaseState();
      setActiveView("projects");
    } catch (error) {
      if (container) container.innerHTML = `<article class="engine-empty"><strong>Demo deletion failed</strong><p>${error.message}</p></article>`;
    }
  });

  document.querySelector("#create-assessment-engine")?.addEventListener("click", async () => {
    const container = document.querySelector("#assessment-engine-dashboard");
    try {
      if (!hasActiveWorkspace()) {
        if (container) container.innerHTML = "<article class=\"engine-empty\"><strong>Open a project first</strong><p>Assessment creation is scoped to one company workspace.</p></article>";
        return;
      }
      if (container) container.innerHTML = "<article class=\"engine-empty\"><strong>Creating assessment...</strong><p>Loading Operations Manager Question Bank v1 into the engine.</p></article>";
      await apiRequest("/api/assessment-engine/assessments", {
        method: "POST",
        body: JSON.stringify({
          projectId: activeProject?.id,
          title: "Operations Manager Assessment MVP"
        })
      });
      await refreshAssessmentEngine();
    } catch (error) {
      if (container) container.innerHTML = `<article class="engine-empty"><strong>Assessment creation failed</strong><p>${error.message}</p></article>`;
    }
  });

  document.querySelector("#run-assessment-engine")?.addEventListener("click", async () => {
    const container = document.querySelector("#assessment-engine-dashboard");
    try {
      if (!hasActiveWorkspace()) {
        if (container) container.innerHTML = "<article class=\"engine-empty\"><strong>Open a project first</strong><p>Analysis is scoped to one company workspace.</p></article>";
        return;
      }
      if (container) container.innerHTML = "<article class=\"engine-empty\"><strong>Running analysis...</strong><p>Generating findings, evidence, recommendations, and roadmap items.</p></article>";
      assessmentEngineState = await apiRequest("/api/assessment-engine/analyze", {
        method: "POST",
        body: JSON.stringify({ projectId: activeProject?.id })
      });
      await refreshAssessmentEngine();
    } catch (error) {
      if (container) container.innerHTML = `<article class="engine-empty"><strong>Analysis failed</strong><p>${error.message}</p></article>`;
    }
  });

  document.addEventListener("click", async (event) => {
    const blueprintAction = event.target.closest("#generate-assessment-blueprint, #create-required-blueprint-sessions, #create-recommended-blueprint-sessions, .mark-role-na");
    if (!blueprintAction) return;
    const container = document.querySelector("#assessment-engine-dashboard");
    try {
      if (!hasActiveWorkspace()) {
        if (container) container.innerHTML = "<article class=\"engine-empty\"><strong>Open a project first</strong><p>Assessment blueprint generation is scoped to one company workspace.</p></article>";
        return;
      }
      if (blueprintAction.id === "generate-assessment-blueprint") {
        if (container) container.innerHTML = "<article class=\"engine-empty\"><strong>Generating blueprint...</strong><p>Reading Organization Profile, stakeholder logic, KPI sets, sessions, findings, and coverage gaps.</p></article>";
        const payload = await apiRequest("/api/assessment-blueprint/generate", {
          method: "POST",
          body: JSON.stringify({ projectId: activeProject?.id })
        });
        assessmentEngineState = { ...(assessmentEngineState || {}), assessmentBlueprint: payload.blueprint };
      } else if (blueprintAction.id === "create-required-blueprint-sessions" || blueprintAction.id === "create-recommended-blueprint-sessions") {
        const level = blueprintAction.id === "create-recommended-blueprint-sessions" ? "recommended" : "required";
        const payload = await apiRequest("/api/assessment-blueprint/sessions", {
          method: "POST",
          body: JSON.stringify({ projectId: activeProject?.id, level })
        });
        assessmentEngineState = { ...(assessmentEngineState || {}), assessmentBlueprint: payload.blueprint };
        await refreshAssessmentEngine();
      } else if (blueprintAction.classList.contains("mark-role-na")) {
        const roleId = blueprintAction.dataset.roleId;
        const reason = window.prompt("Why is this stakeholder not applicable?") || "Not applicable for this assessment phase.";
        const payload = await apiRequest("/api/assessment-blueprint/not-applicable", {
          method: "PATCH",
          body: JSON.stringify({ projectId: activeProject?.id, roleId, reason })
        });
        assessmentEngineState = { ...(assessmentEngineState || {}), assessmentBlueprint: payload.blueprint };
      }
      await refreshAssessmentEngine();
    } catch (error) {
      if (container) container.innerHTML = `<article class="engine-empty"><strong>Blueprint action failed</strong><p>${error.message}</p></article>`;
    }
  });

  document.addEventListener("submit", async (event) => {
    if (event.target.id === "krb-issue-form") {
      event.preventDefault();
      const payload = Object.fromEntries(new FormData(event.target).entries());
      await apiRequest("/api/operations-center/issues", {
        method: "POST",
        body: JSON.stringify({ ...payload, source: "manual" })
      });
      event.target.reset();
      await refreshKrbOperationsCenter();
      return;
    }
    if (event.target.id === "krb-qa-run-form") {
      event.preventDefault();
      const payload = Object.fromEntries(new FormData(event.target).entries());
      await apiRequest("/api/operations-center/qa-runs", {
        method: "POST",
        body: JSON.stringify({
          ...payload,
          cleanup_status: "not_applicable",
          checks_json: [{ name: "Manual QA record", status: payload.status || "passed" }],
          failed_checks_json: payload.status === "failed" ? [{ name: "Manual QA record", status: "failed" }] : []
        })
      });
      event.target.reset();
      await refreshKrbOperationsCenter();
      return;
    }
    if (event.target.id !== "assessment-participant-form") return;
  });

  document.addEventListener("change", (event) => {
    if (event.target.id === "participant-role-filter") {
      participantRoleFilter = event.target.value;
      localStorage.setItem("participantRoleFilter", participantRoleFilter);
    }
    if (event.target.id === "participant-group-filter") {
      participantGroupFilter = event.target.value;
      localStorage.setItem("participantGroupFilter", participantGroupFilter);
    }
    if (event.target.id === "participant-status-filter") {
      participantStatusFilter = event.target.value;
      localStorage.setItem("participantStatusFilter", participantStatusFilter);
    }
  });

  document.addEventListener("click", async (event) => {
  });

  document.addEventListener("input", (event) => {
    if (activeRespondToken) return;
    if (!event.target.closest("#respondent-assessment-form")) return;
    window.clearTimeout(respondentSaveTimer);
    respondentSaveTimer = window.setTimeout(() => saveRespondentProgress(), 700);
  });

  document.addEventListener("change", (event) => {
    if (activeRespondToken) return;
    if (!event.target.closest("#respondent-assessment-form")) return;
    window.clearTimeout(respondentSaveTimer);
    respondentSaveTimer = window.setTimeout(() => saveRespondentProgress(), 200);
  });

  document.addEventListener("click", (event) => {
    if (activeRespondToken) return;
    const rankButton = event.target.closest(".respondent-rank-option");
    if (rankButton) {
      const control = rankButton.closest(".respondent-ranking-control");
      if (!control || respondentAssessmentState?.session?.status === "completed") return;
      const current = [...control.querySelectorAll("[data-rank-selected]")].map((item) => item.dataset.rankSelected);
      const value = rankButton.dataset.rankOption;
      const next = current.includes(value) ? current.filter((item) => item !== value) : [...current, value];
      const selected = control.querySelector(".respondent-ranking-selected");
      selected.innerHTML = next.length
        ? next.map((item, index) => `<span data-rank-selected="${escapeHtml(item)}">${index + 1}. ${escapeHtml(item)}</span>`).join("")
        : "<small>No ranking selected yet.</small>";
      control.querySelectorAll(".respondent-rank-option").forEach((button) => {
        const rankIndex = next.indexOf(button.dataset.rankOption);
        button.classList.toggle("active", rankIndex >= 0);
        button.textContent = rankIndex >= 0 ? `${rankIndex + 1}. ${button.dataset.rankOption}` : button.dataset.rankOption;
      });
      window.clearTimeout(respondentSaveTimer);
      respondentSaveTimer = window.setTimeout(() => saveRespondentProgress(), 300);
      return;
    }
    if (event.target.closest("#respondent-save")) {
      event.preventDefault();
      saveRespondentProgress();
    }
    if (event.target.closest("#respondent-continue-later")) {
      event.preventDefault();
      saveRespondentProgress();
      window.alert("Your progress has been saved. You can continue later using this same link.");
    }
  });

  document.addEventListener("submit", (event) => {
    if (activeRespondToken) return;
    if (event.target.id !== "respondent-assessment-form") return;
    event.preventDefault();
    saveRespondentProgress({ complete: true });
  });

  document.querySelector("#sign-out")?.addEventListener("click", async () => {
    try {
      await apiRequest("/api/auth/logout", { method: "POST" });
    } catch {
      // Local cleanup still matters if the server session is already gone.
    }
    currentUserEmail = "";
    currentUser = null;
    currentRole = "participant";
    clearActiveWorkspace();
    clearSession();
    shouldOpenAppShell = false;
    history.replaceState({}, "", location.pathname);
    showPublicHomepageForSavedSession();
    document.querySelector("#auth-screen").classList.remove("hidden");
  });

  document.querySelector("#user-role-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const name = document.querySelector("#role-user-name").value.trim();
    const email = normalizeEmail(document.querySelector("#role-user-email").value);
    const role = document.querySelector("#role-user-role").value;
    const projectId = document.querySelector("#role-user-project").value || activeProject?.id;
    const password = document.querySelector("#role-user-password").value.trim();
    try {
      const payload = await apiRequest("/api/users", {
        method: "POST",
        body: JSON.stringify({
          name,
          email,
          role,
          ...(password ? { password } : {}),
          projectId
        })
      });
      storePlatformUser(payload.user);
      mergeState("platform", { users: platformUsers ?? {} });
      refreshPlatformSurfaceFromStore();
      event.currentTarget.reset();
      renderProjectAccessOptions();
      document.querySelector("#share-box").innerHTML = `<strong>User saved</strong><p>${email} has ${role} access for the selected project. Use Send Credentials when ready.</p>`;
    } catch (error) {
      document.querySelector("#share-box").innerHTML = `<strong>User save failed</strong><p>${error.message}</p>`;
    }
  });

  document.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-send-credentials]");
    if (button) {
      sendCredentials(button.dataset.sendCredentials);
    }

    const editButton = event.target.closest("[data-edit-user]");
    if (editButton) {
      const user = platformUsers[editButton.dataset.editUser];
      if (!user) return;
      document.querySelector("#role-user-name").value = user.name || "";
      document.querySelector("#role-user-email").value = user.email || "";
      document.querySelector("#role-user-role").value = user.role || "participant";
      document.querySelector("#role-user-project").value = user.projectId || activeProject?.id || "";
      document.querySelector("#role-user-password").value = "";
      document.querySelector("#share-box").innerHTML = `<strong>Editing user</strong><p>${user.email}</p>`;
    }

    const statusButton = event.target.closest("[data-user-status]");
    if (statusButton) {
      const userId = statusButton.dataset.userStatus;
      const status = statusButton.dataset.statusValue;
      const user = Object.values(platformUsers).find((item) => item.id === userId);
      if (!user) return;
      try {
        const payload = await apiRequest(`/api/users/${encodeURIComponent(userId)}`, {
          method: "PATCH",
          body: JSON.stringify({
            status,
            role: user.role,
            projectId: user.projectId || activeProject?.id
          })
        });
        storePlatformUser(payload.user);
        mergeState("platform", { users: platformUsers ?? {} });
        refreshPlatformSurfaceFromStore();
        document.querySelector("#share-box").innerHTML = `<strong>User ${status === "disabled" ? "disabled" : "reactivated"}</strong><p>${user.email}</p>`;
      } catch (error) {
        document.querySelector("#share-box").innerHTML = `<strong>User update failed</strong><p>${error.message}</p>`;
      }
    }
  });
  document.addEventListener("change", (event) => {
    if (event.target?.id === "owner-stakeholder-group-filter") {
      ownerStakeholderGroupFilter = event.target.value;
      localStorage.setItem("ownerStakeholderGroupFilter", ownerStakeholderGroupFilter);
    }
    if (event.target?.id === "owner-stakeholder-role-filter") {
      ownerStakeholderRoleFilter = event.target.value;
      localStorage.setItem("ownerStakeholderRoleFilter", ownerStakeholderRoleFilter);
    }
    if (event.target?.id === "owner-heatmap-domain-filter") {
      ownerHeatmapDomainFilter = event.target.value;
      localStorage.setItem("ownerHeatmapDomainFilter", ownerHeatmapDomainFilter);
    }
    if (event.target?.id === "owner-heatmap-group-filter") {
      ownerHeatmapGroupFilter = event.target.value;
      localStorage.setItem("ownerHeatmapGroupFilter", ownerHeatmapGroupFilter);
    }
    if (event.target?.id === "owner-heatmap-min-priority") {
      ownerHeatmapMinPriority = event.target.value || "0";
      localStorage.setItem("ownerHeatmapMinPriority", ownerHeatmapMinPriority);
    }
    if (event.target?.id === "owner-heatmap-only-misalignment") {
      ownerHeatmapOnlyMisalignment = Boolean(event.target.checked);
      localStorage.setItem("ownerHeatmapOnlyMisalignment", String(ownerHeatmapOnlyMisalignment));
    }
    if (event.target?.id === "owner-heatmap-only-high-confidence") {
      ownerHeatmapOnlyHighConfidence = Boolean(event.target.checked);
      localStorage.setItem("ownerHeatmapOnlyHighConfidence", String(ownerHeatmapOnlyHighConfidence));
    }
  });
}

async function loadProductionQuestionBanks() {
  try {
    const [
      dispatcherResponse,
      technicianResponse,
      branchManagerResponse,
      warehouseInventoryResponse,
      financeManagerResponse,
      salesManagerResponse,
      customerAssessmentResponse,
      servicePartnerResponse,
      supplierResponse,
      itSystemsResponse,
      hrWorkforceResponse
    ] = await Promise.all([
      fetch("/database/question_bank_dispatcher_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_technician_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_branch_manager_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_warehouse_inventory_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_finance_manager_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_sales_manager_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_customer_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_service_partner_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_supplier_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_it_systems_v1.json", { cache: "no-store" }),
      fetch("/database/question_bank_hr_workforce_v1.json", { cache: "no-store" })
    ]);
    if (!dispatcherResponse.ok) throw new Error("Dispatcher question bank could not be loaded.");
    if (!technicianResponse.ok) throw new Error("Technician question bank could not be loaded.");
    if (!branchManagerResponse.ok) throw new Error("Branch Manager question bank could not be loaded.");
    if (!warehouseInventoryResponse.ok) throw new Error("Warehouse / Inventory question bank could not be loaded.");
    if (!financeManagerResponse.ok) throw new Error("Finance Manager question bank could not be loaded.");
    if (!salesManagerResponse.ok) throw new Error("Sales Manager question bank could not be loaded.");
    if (!customerAssessmentResponse.ok) throw new Error("Customer assessment could not be loaded.");
    if (!servicePartnerResponse.ok) throw new Error("Service Partner assessment could not be loaded.");
    if (!supplierResponse.ok) throw new Error("Supplier assessment could not be loaded.");
    if (!itSystemsResponse.ok) throw new Error("IT / Systems assessment could not be loaded.");
    if (!hrWorkforceResponse.ok) throw new Error("HR / Workforce assessment could not be loaded.");
    const dispatcherPayload = await dispatcherResponse.json();
    const technicianPayload = await technicianResponse.json();
    const branchManagerPayload = await branchManagerResponse.json();
    const warehouseInventoryPayload = await warehouseInventoryResponse.json();
    const financeManagerPayload = await financeManagerResponse.json();
    const salesManagerPayload = await salesManagerResponse.json();
    const customerAssessmentPayload = await customerAssessmentResponse.json();
    const servicePartnerPayload = await servicePartnerResponse.json();
    const supplierPayload = await supplierResponse.json();
    const itSystemsPayload = await itSystemsResponse.json();
    const hrWorkforcePayload = await hrWorkforceResponse.json();
    dispatcherQuestionBankV1 = dispatcherPayload.dispatcher_question_bank_v1_revised || dispatcherPayload.dispatcher_question_bank_v1 || [];
    technicianQuestionBankV1 = technicianPayload.technician_question_bank_v1 || [];
    branchManagerQuestionBankV1 = branchManagerPayload.branch_manager_question_bank_v1_revised || branchManagerPayload.branch_manager_question_bank_v1 || [];
    warehouseInventoryQuestionBankV1 = warehouseInventoryPayload.warehouse_inventory_question_bank_v1_revised || warehouseInventoryPayload.warehouse_inventory_question_bank_v1 || [];
    financeManagerQuestionBankV1 = financeManagerPayload.finance_manager_question_bank_v1_revised || financeManagerPayload.finance_manager_question_bank_v1 || [];
    salesManagerQuestionBankV1 = salesManagerPayload.sales_manager_question_bank_v1_revised || salesManagerPayload.sales_manager_question_bank_v1 || [];
    customerAssessmentV1 = customerAssessmentPayload.customer_assessment_v1_revised || customerAssessmentPayload.customer_assessment_v1 || [];
    servicePartnerAssessmentV1 = servicePartnerPayload.service_partner_assessment_v1 || [];
    supplierAssessmentV1 = supplierPayload.supplier_assessment_v1 || [];
    itSystemsAssessmentV1 = itSystemsPayload.it_systems_assessment_v1 || [];
    hrWorkforceAssessmentV1 = hrWorkforcePayload.hr_workforce_assessment_v1 || [];
    const dispatcherRole = questionBankRoles.find((role) => role.key === "dispatcher");
    if (dispatcherRole) {
      dispatcherRole.questions = dispatcherQuestionBankV1;
      dispatcherRole.version = dispatcherQuestionBankV1.length ? "v1" : "pending";
    }
    const branchManagerRole = questionBankRoles.find((role) => role.key === "branch-manager");
    if (branchManagerRole) {
      branchManagerRole.questions = branchManagerQuestionBankV1;
      branchManagerRole.version = branchManagerQuestionBankV1.length ? "v1" : "pending";
    }
    for (const key of ["technician", "field-service-technician"]) {
      const role = questionBankRoles.find((item) => item.key === key);
      if (role) {
        role.questions = technicianQuestionBankV1;
        role.version = technicianQuestionBankV1.length ? "v1" : "pending";
      }
    }
    for (const key of ["warehouse-manager", "inventory-coordinator"]) {
      const role = questionBankRoles.find((item) => item.key === key);
      if (role) {
        role.questions = warehouseInventoryQuestionBankV1;
        role.version = warehouseInventoryQuestionBankV1.length ? "v1" : "pending";
      }
    }
    const financeManagerRole = questionBankRoles.find((role) => role.key === "finance-manager");
    if (financeManagerRole) {
      financeManagerRole.questions = financeManagerQuestionBankV1;
      financeManagerRole.version = financeManagerQuestionBankV1.length ? "v1" : "pending";
    }
    const salesManagerRole = questionBankRoles.find((role) => role.key === "sales-manager");
    if (salesManagerRole) {
      salesManagerRole.questions = salesManagerQuestionBankV1;
      salesManagerRole.version = salesManagerQuestionBankV1.length ? "v1" : "pending";
    }
    for (const key of ["fleet-customer", "dealer-customer", "retail-customer"]) {
      const role = questionBankRoles.find((item) => item.key === key);
      if (role) {
        role.questions = customerAssessmentV1;
        role.version = customerAssessmentV1.length ? "v1" : "pending";
      }
    }
    const servicePartnerRole = questionBankRoles.find((role) => role.key === "service-partner");
    if (servicePartnerRole) {
      servicePartnerRole.questions = servicePartnerAssessmentV1;
      servicePartnerRole.version = servicePartnerAssessmentV1.length ? "v1" : "pending";
    }
    const supplierRole = questionBankRoles.find((role) => role.key === "supplier");
    if (supplierRole) {
      supplierRole.questions = supplierAssessmentV1;
      supplierRole.version = supplierAssessmentV1.length ? "v1" : "pending";
    }
    const itManagerRole = questionBankRoles.find((role) => role.key === "it-manager");
    if (itManagerRole) {
      itManagerRole.questions = itSystemsAssessmentV1;
      itManagerRole.version = itSystemsAssessmentV1.length ? "v1" : "pending";
    }
    const hrManagerRole = questionBankRoles.find((role) => role.key === "hr-manager");
    if (hrManagerRole) {
      hrManagerRole.questions = hrWorkforceAssessmentV1;
      hrManagerRole.version = hrWorkforceAssessmentV1.length ? "v1" : "pending";
    }
    mergeState("framework", { roles: questionBankRoles ?? [] });
    setState("session", "activeQuestionBankRole", activeQuestionBankRole);
    refreshPlatformSurfaceFromStore();
  } catch (error) {
    console.warn(error.message);
  }
}

wireEvents();
loadProductionQuestionBanks();
const sessionRestored = activeRespondToken ? false : restoreSession();
if (!sessionRestored && !activeResetToken) {
  applyRole(activeContextToken || activeSurveyToken || activeRespondToken ? "participant" : resolveRoleForEmail(currentUserEmail));
}
// Validate session with server immediately after local restore.
// Runs async — UI loads instantly from localStorage, but if server rejects
// the cookie (disabled account, expired, revoked), handleAuthExpired() fires
// within milliseconds without user action required.
if (sessionRestored && !activeRespondToken) {
  fetch("/api/auth/me", { credentials: "same-origin" }).then((r) => {
    if (!r.ok) handleAuthExpired("Session expired. Please sign in again.");
  }).catch(() => { /* network error — keep session, next API call will catch it */ });
}
if (!activeRespondToken) {
  showPublicHomepageForSavedSession();
}


if (activeRespondToken) {
  document.querySelector("#auth-screen")?.classList.add("hidden");
  document.querySelector(".app-shell")?.classList.add("hidden");
  import("./participant.js").then((participantSurface) => participantSurface.init());
} else if (activeContextToken) {
  loadPublicContextIntake();
} else if (activeSurveyToken) {
  document.querySelector("#auth-screen").classList.add("hidden");
  setActiveView("surveys");
  document.querySelector("#view-title").textContent = "Survey Response";
  loadActiveSurveyAssignment();
} else if (location.pathname === "/operations-center" && sessionRestored && currentRole === "platform_owner") {
  document.querySelector("#auth-screen").classList.add("hidden");
  setActiveView("operations-center");
  refreshKrbOperationsCenter();
} else if (activeResetToken) {
  showAuthPanel();
} else if (sessionRestored && shouldOpenAppShell) {
  openAuthenticatedApp();
} else if (!sessionRestored && shouldOpenAppShell) {
  showAuthPanel();
}

// RESET_LINK_FIX — reset link always shows the set-password form, never the app shell.
if (activeResetToken) {
  document.querySelector(".app-shell")?.classList.add("hidden");
  document.querySelector("#auth-screen")?.classList.remove("hidden");
  const _rlLoad = document.querySelector("#app-loading"); if (_rlLoad) _rlLoad.style.display = "none";
  document.querySelector("#auth-form")?.classList.add("hidden");
  document.querySelector("#forgot-password-form")?.classList.add("hidden");
  document.querySelector("#forgot-password-button")?.classList.add("hidden");
  document.querySelector("#reset-password-form")?.classList.remove("hidden");
  const _rlT = document.querySelector("#auth-title"); if (_rlT) _rlT.textContent = "Reset password";
  const _rlS = document.querySelector("#auth-subtitle"); if (_rlS) _rlS.textContent = "Choose a new password for your assessment platform account.";
}
// ─── Platform session bootstrap ───────────────────────────────────────────────

function authHeaders() {
  // Token no longer in localStorage or Authorization header.
  // HttpOnly cookie is sent automatically by the browser for all same-origin requests.
  return {};
}

async function initPlatformSession() {
  // Called after successful login, replaces direct shell routing for bi/tenant-admin users
  // Pre-hide the old assessment shell immediately (before the async fetch) so there
  // is no flash of sidebar/topbar while waiting for the /api/platform/me response.
  // Also set __platformSessionPending so applyRole() skips showing role-specific
  // surfaces (e.g. #owner-surface) while this async check is in flight.
  // Use currentUserEmail (set from localStorage in restoreSession) as the "has a session" signal —
  // currentSessionToken is now memory-only and is "" on page reload until after login.
  if (currentSessionToken || currentUserEmail) {
    window.__platformSessionPending = true;
    ['.sidebar', '.topbar', '#workspace-shell-panel', '.main', '.app-shell'].forEach(function(sel) {
      const el = document.querySelector(sel);
      if (el) el.style.display = 'none';
    });
    const _plLoad = document.querySelector('#app-loading'); if (_plLoad) _plLoad.style.display = 'flex';
  }
  try {
    const res = await fetch("/api/platform/me", { credentials: "same-origin" });
    if (!res.ok) {
      window.__platformSessionPending = false;
      const errBody = await res.json().catch(() => ({}));
      const msg = res.status === 401
        ? "Session invalid. Please sign in again."
        : res.status === 403
          ? (errBody.error || "Access denied. Contact your administrator.")
          : `Platform access failed (${res.status}). Contact support.`;
      handleAuthExpired(msg);
      return false;
    }
    const me = await res.json();
    // platform_owner has tenantId: null by design — they have global access
    if (!me.tenantId && me.tenantRole !== "platform_owner") {
      window.__platformSessionPending = false;
      handleAuthExpired("Platform workspace not configured for this account. Contact your Derive account manager.");
      return false;
    }
    window.__platformSessionPending = false;
    window.__platformMe = me;

    // Always offer tenant-admin surface if user has that role
    if (me.tenantRole === "tenant_admin" || me.tenantRole === "platform_owner") {
      await loadTenantAdminSurface(me);
    }

    // REP_LANDING_V1 — Saha temsilcisi (moduleRole 'rep') BI kabugunu YUKLEMEZ.
    // Ona 'rakip' departmani API erisimi icin verildi; piyasa verisini Saha'daki
    // "🏷 Rakip Fiyatlar" sekmesinden goruyor. 485KB'lik masaustu kabugu mobilde
    // acmak yanlis — ustelik hideAllSurfacesExcept onu BI'da baslatiyordu.
    const _sahaSub = (me.subscriptions || []).find(x => x.moduleId === "saha");
    const _sahaRep = _sahaSub && _sahaSub.moduleRole === "rep";
    const _hasIntel = (me.subscriptions || []).some(s => s.moduleId === "intelligence" && (s.moduleRole === "manager" || s.moduleRole === "admin")); /* REPONLY_V2 — intel:viewer sadece rakip API granti, BI koltugu degil; saha-rep+viewer hala rep-only, BI kabugu YOK */
    const _repOnly = _sahaRep && !_hasIntel; /* REPONLY_V1 — sadece saha-rep (intelligence YOK) BI'i bastirir; dual kullanici masaustunde BI gorur */
    // MOBIL_YONLENDIRME_V1 — native (Capacitor) app'te ya da ?saha=1 ile HERKES saha resepsiyonuna düşer; BI masaüstü kabuğu mobilde açılmaz.
    const _nativeMobil = (typeof window !== "undefined") && (((window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform())) || (new URLSearchParams(location.search).has("saha")));
    const _mobilSaha = _nativeMobil && !!_sahaSub;

    // Load module shells for each active subscription
    for (const sub of me.subscriptions || []) {
      if (sub.moduleId === "intelligence") {
        if (_repOnly || _mobilSaha) continue;          // temsilci VEYA mobil: BI kabugu YOK
        await loadBiSurface(me, sub);
      } else if (sub.moduleId === "saha") {
        // SAHA_DESKTOP_V1 — masaüstünde (BI'lı, temsilci değil) mobil saha.js ÖN-YÜKLENMEZ;
        // Saha üst menü sekmesinden saha_desktop.js açılır. Mobil / temsilci / saha-only: eskisi gibi saha.js.
        const _dualDesktop = !_nativeMobil && !_repOnly && (me.subscriptions || []).some(s => s.moduleId === "intelligence");
        if (!_dualDesktop) await loadSahaSurface(me, sub);
      }
      // Future modules: add more cases here
    }

    // Birden fazla modül varsa: BI varsayılan görünür, sağ altta modül geçiş düğmesi
    const moduleIds = (me.subscriptions || [])
      .filter(s => !(_repOnly && s.moduleId === "intelligence"))   // REP_LANDING_V1
      .map(s => s.moduleId);
    if (moduleIds.includes("intelligence") && moduleIds.includes("saha")) {
      if (_mobilSaha) {
        // MOBIL_YONLENDIRME_V1 — mobil: BI değil, saha resepsiyonu görünür.
        hideAllSurfacesExcept("saha-surface");
      } else {
        hideAllSurfacesExcept("bi-surface");
        const biEl = document.getElementById("bi-surface");
        if (biEl) biEl.style.display = "block";
        // SAHA_DESKTOP_V1 — sağ-alt yüzen "📍 Saha" düğmesi kaldırıldı; Saha artık BI üst menüsünde sekme.
      }
    }
    // ADMIN_PANEL_V1 — Yonetim paneli DOM'a yuklendi ama hideAllSurfacesExcept onu
    // gizliyordu ve ona gidecek dugme YOKTU. Tenant admin icin gecis dugmesi ekle.
    if (me.tenantRole === "tenant_admin" || me.tenantRole === "platform_owner") {
      addTenantAdminToggle();
    }

    // If no module subscriptions, user is in the platform but no modules yet
    if (!me.subscriptions?.length && me.tenantRole !== "tenant_admin" && me.tenantRole !== "platform_owner") {
      showPlatformNoAccessMessage();
    }

    // Surfaces are loaded — hide the auth/loading overlay (z-index:9999) so they are visible.
    // When applyRole() detects __platformSessionPending it returns early without hiding
    // #auth-screen, so we must do it here after the async surface load completes.
    document.querySelector("#auth-screen")?.classList.add("hidden");

    const _plDone = document.querySelector("#app-loading"); if (_plDone) _plDone.style.display = "none";
    return true; // handled — caller should not route to regular shells
  } catch (err) {
    console.error("[platform] initPlatformSession error:", err);
    window.__platformSessionPending = false;
    // Show login screen so user is not left on a dark screen
    handleAuthExpired("Bağlantı hatası. Lütfen sayfayı yenileyin.");
    return false;
  }
}

// ─── Surface loaders ──────────────────────────────────────────────────────────

async function loadBiSurface(me, sub) {
  const container = document.getElementById("bi-surface");
  if (!container) return;

  hideAllSurfacesExcept("bi-surface");
  container.style.display = "block";

  try {
    const { initBiSurface } = await import("/shells/bi.js?v=20260723-1");
    initBiSurface(container, me, sub, buildBiCallbacks(me, sub));
  } catch (err) {
    container.innerHTML = `<div class="platform-error">Derive Intelligence yüklenemedi: ${err.message}</div>`;
    console.error("[platform] bi surface load error:", err);
  }
}

async function loadSahaSurface(me, sub) {
  const container = document.getElementById("saha-surface");
  if (!container) return;

  hideAllSurfacesExcept("saha-surface");
  // overflow:hidden — saha-app handles its own scroll via flex layout
  container.style.cssText = "display:block;position:fixed;top:0;left:0;right:0;bottom:0;z-index:100;overflow:hidden;width:100%;max-width:100%;";

  try {
    const { initSahaSurface } = await import("/shells/saha.js?v=20260714-2");
    initSahaSurface(container, me, sub, { authHeaders });
  } catch (err) {
    container.innerHTML = `<div class="platform-error">Saha yüklenemedi: ${err.message}</div> <!-- DEKRB_APP_V1 -->`;
    console.error("[platform] saha surface load error:", err);
  }
}

// SAHA_DESKTOP_V1 — masaüstü Saha modülü (ayrı: shells/saha_desktop.js). BI üst menüsündeki
// "Saha" sekmesinden açılır. saha-surface içine bir kez mount edilir; sonra göster/gizle.
let __sahaDesktopInited = false;
async function openSahaDesktop(me, sub) {
  const container = document.getElementById("saha-surface");
  if (!container) return;
  const _sahaSub = (me.subscriptions || []).find(x => x.moduleId === "saha") || sub || {};
  if (!__sahaDesktopInited) {
    container.style.cssText = "display:block;position:fixed;top:0;left:0;right:0;bottom:0;z-index:100;overflow:hidden;width:100%;max-width:100%;";
    try {
      const { initSahaDesktop } = await import("/shells/saha_desktop.js?v=20260724-10");
      initSahaDesktop(container, me, _sahaSub, {
        authHeaders,
        canExit: true,
        onExit: () => {
          const s = document.getElementById("saha-surface"); if (s) s.style.display = "none";
          const b = document.getElementById("bi-surface"); if (b) b.style.display = "block";
        }
      });
      __sahaDesktopInited = true;
    } catch (err) {
      container.innerHTML = `<div class="platform-error">Derive Saha yüklenemedi: ${err.message}</div>`;
      console.error("[platform] saha_desktop load error:", err);
      return;
    }
  }
  const b = document.getElementById("bi-surface"); if (b) b.style.display = "none";
  container.style.display = "block";
}

// BI ⇄ Saha geçiş düğmesi (iki modüle de erişimi olan kullanıcılar için)
function addSahaModuleToggle() {
  if (document.getElementById("saha-module-toggle")) return;
  const btn = document.createElement("button");
  btn.id = "saha-module-toggle";
  btn.textContent = "📍 Saha";
  const _isMobile = window.innerWidth < 768;
  btn.style.cssText = "position:fixed;bottom:calc(" + (_isMobile ? "80px" : "18px") + " + env(safe-area-inset-bottom, 0px));right:18px;z-index:99999;background:#0f172a;color:#fff;border:0;border-radius:24px;padding:11px 18px;font-size:14px;font-weight:700;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.3);touch-action:manipulation;";
  btn.addEventListener("click", () => {
    const saha = document.getElementById("saha-surface");
    const bi = document.getElementById("bi-surface");
    const mhub = document.getElementById("krb-mhub"); // mobile hub overlay (z-index:10000)
    const sahaGorunur = saha && saha.style.display !== "none";
    if (sahaGorunur) {
      // Switch back to BI: restore mobile hub overlay
      hideAllSurfacesExcept("bi-surface");
      if (bi) bi.style.display = "block";
      if (mhub) mhub.style.display = "flex";
      btn.textContent = "📍 Saha";
    } else {
      // Switch to Saha: hide mobile hub so saha-surface (z-index:100) is visible
      hideAllSurfacesExcept("saha-surface");
      if (saha) saha.style.display = "block";
      if (mhub) mhub.style.display = "none";
      btn.textContent = "📊 BI";
    }
  });
  document.body.appendChild(btn);
  // Re-anchor the button if any async DOM operation removes it
  new MutationObserver(function() {
    if (!document.getElementById("saha-module-toggle")) {
      document.body.appendChild(btn);
    }
  }).observe(document.body, { childList: true });
}

// ADMIN_PANEL_V1 — Yonetim paneline gecis dugmesi (tenant_admin / platform_owner)
function addTenantAdminToggle() {
  if (document.getElementById("tenant-admin-toggle")) return;
  const btn = document.createElement("button");
  btn.id = "tenant-admin-toggle";
  btn.textContent = "👤 Yönetim";
  btn.style.cssText = "position:fixed;right:16px;bottom:70px;z-index:2000;padding:10px 16px;"
    + "border-radius:24px;border:1px solid #e2b04a;background:#1a1a2e;color:#e2b04a;"
    + "font-size:13px;font-weight:600;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.35)";
  btn.addEventListener("click", function() {
    const ta = document.getElementById("tenant-admin-surface");
    const acik = ta && ta.style.display !== "none" && ta.style.display !== "";
    if (acik) {
      // Yonetimden CIK -> BI'ya don
      hideAllSurfacesExcept("bi-surface");
      const bi = document.getElementById("bi-surface");
      if (bi) bi.style.display = "block";
      btn.textContent = "👤 Yönetim";
    } else {
      hideAllSurfacesExcept("tenant-admin-surface");
      if (ta) ta.style.display = "block";
      btn.textContent = "← Geri";
    }
  });
  document.body.appendChild(btn);
  // Baska bir async islem dugmeyi silerse geri koy
  new MutationObserver(function() {
    if (!document.getElementById("tenant-admin-toggle")) document.body.appendChild(btn);
  }).observe(document.body, { childList: true });
}

async function loadTenantAdminSurface(me) {
  const container = document.getElementById("tenant-admin-surface");
  if (!container) return;

  // Tenant-admin surface coexists alongside module surfaces (shown as sidebar/header)
  // so we don't call hideAllSurfacesExcept here

  try {
    const { initTenantAdminSurface } = await import("/shells/tenant-admin.js");
    initTenantAdminSurface(container, me, buildTenantAdminCallbacks());
  } catch (err) {
    console.error("[platform] tenant-admin surface load error:", err);
  }
}

// ─── Surface helpers ──────────────────────────────────────────────────────────

function hideAllSurfacesExcept(keepId) {
  document.querySelectorAll('[id$="-surface"]').forEach(el => {
    if (el.id !== keepId) el.style.display = "none";
  });
}

function showPlatformNoAccessMessage() {
  hideAllSurfacesExcept(null);
  const msg = document.createElement("div");
  msg.id = "platform-no-access";
  msg.style.cssText = "display:flex;align-items:center;justify-content:center;height:80vh;flex-direction:column;gap:16px;font-family:sans-serif;color:#555;";
  msg.innerHTML = `
    <svg width="48" height="48" fill="none" stroke="#bbb" stroke-width="1.5" viewBox="0 0 24 24">
      <circle cx="12" cy="12" r="10"/><path d="M12 8v4m0 4h.01"/>
    </svg>
    <h2 style="margin:0;font-size:20px;color:#333;">Henüz aktif modülünüz yok</h2>
    <p style="margin:0;text-align:center;max-width:380px;line-height:1.5;">
      Platform yöneticiniz size bir modül erişimi tanımladığında burada görünecek.
    </p>
  `;
  document.body.appendChild(msg);
}

// ─── Callback factories ───────────────────────────────────────────────────────

function buildBiCallbacks(me, sub) {
  return {
    // SAHA_DESKTOP_V1 — BI üst menüsündeki "Saha" sekmesi bunu çağırır
    openSaha: () => openSahaDesktop(me, sub),
    // Fetch wrapper with auth headers
    apiFetch: async (path, opts = {}) => {
      const res = await fetch(path, {
        ...opts,
        cache: 'no-store',
        headers: { ...authHeaders(), ...(opts.headers || {}) }
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: res.statusText }));
        throw Object.assign(new Error(err.error || "Request failed"), { status: res.status });
      }
      return res.json();
    },

    // Streaming chat callback — calls handler(chunkText) for each token
    streamChat: async (dept, message, handler) => {
      const res = await fetch(`/api/bi/department/${dept}/chat`, {
        method: "POST",
        headers: { ...authHeaders(), "Content-Type": "application/json" },
        body: JSON.stringify({ message })
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: res.statusText }));
        throw new Error(err.error || "Chat request failed");
      }
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop();
        for (const line of lines) {
          if (line.startsWith("data: ")) {
            const data = line.slice(6).trim();
            if (data === "[DONE]") return;
            try {
              const parsed = JSON.parse(data);
              if (parsed.text) handler(parsed.text);
            } catch { /* ignore malformed SSE */ }
          }
        }
      }
    },

    // Logout
    logout: async () => {
      window.__platformMe = null;
      try { await apiRequest("/api/auth/logout", { method: "POST" }); } catch {}
      currentUserEmail = "";
      currentUser = null;
      currentRole = "participant";
      clearActiveWorkspace();
      clearSession();
      shouldOpenAppShell = false;
      history.replaceState({}, "", location.pathname);
      // Hide all platform surfaces (bi-surface, saha-surface, etc.) — they are
      // fixed full-page divs that sit above #auth-screen in z-order.
      hideAllSurfacesExcept(null);
      document.querySelector(".app-shell")?.classList.add("hidden");
      document.querySelector("#auth-screen")?.classList.remove("hidden");
      document.querySelector("#login-section")?.classList.remove("hidden");
      document.querySelector("#auth-form")?.classList.remove("hidden");
      document.querySelector("#forgot-password-button")?.classList.remove("hidden");
      document.querySelector("#auth-title") && (document.querySelector("#auth-title").textContent = "Welcome back");
      document.querySelector("#auth-subtitle") && (document.querySelector("#auth-subtitle").textContent = "Access the assessment command center.");
      showPublicHomepageForSavedSession();
    }
  };
}

function buildTenantAdminCallbacks() {
  return {
    apiFetch: async (path, opts = {}) => {
      const res = await fetch(path, {
        ...opts,
        cache: 'no-store',
        headers: { ...authHeaders(), ...(opts.headers || {}) }
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: res.statusText }));
        throw Object.assign(new Error(err.error || "Request failed"), { status: res.status });
      }
      return res.json();
    },
    switchToModule: async (moduleId) => {
      const me = window.__platformMe;
      const sub = me?.subscriptions?.find(s => s.moduleId === moduleId);
      if (moduleId === "intelligence" && sub) {
        await loadBiSurface(me, sub);
      }
    }
  };
}

/* ═══════════════════════════════════════════════════════════════════════════
   FACEID_V1 — Face ID (biyometrik) kilit + Keychain girisi.
   NATIVE-ONLY: Capacitor native app disinda (masaustu/Android tarayici) SIFIR etki (kural 12).
   Plugin (@capgo/capacitor-native-biometric) yoksa TAMAMEN no-op — native rebuild oncesi guvenli.
   Guvenlik: kilit ekraninda HER ZAMAN "Sifre ile gir" cikisi vardir -> kimse kilitli kalamaz.
   ═══════════════════════════════════════════════════════════════════════════ */
(function () {
  "use strict";
  try {
    var CAP = window.Capacitor;
    var isNative = !!(CAP && CAP.isNativePlatform && CAP.isNativePlatform());
    if (!isNative) return;
    var BIO = CAP.Plugins && CAP.Plugins.NativeBiometric;
    if (!BIO) return; // plugin native tarafta yoksa hic dokunma

    var SERVER = "krb.deriveglobal.com";
    var FLAG = "derive_faceid_on";
    var LASTK = "derive_faceid_last";
    var IDLE_MS = 30 * 60 * 1000; // LOGOUT_IDLE_FIX_V1 — arka planda 30 dk+ ise tekrar kilitle (eski 3 dk saha icin cok agresifti; rep her cep-koymada Face ID + basarisizsa logout oluyordu)

    var pendCreds = null;   // manuel giriste yakalanan email+sifre (basari beklenir)
    var enrolling = false;  // enroll UI acik mi
    var gating = false;     // kilit ekrani acik mi
    var enrolled = false;
    try { enrolled = localStorage.getItem(FLAG) === "1"; } catch (e) {}

    function now() { return Date.now(); }
    function touch() { try { localStorage.setItem(LASTK, String(now())); } catch (e) {} }
    function lastActive() { var v = 0; try { v = parseInt(localStorage.getItem(LASTK) || "0", 10); } catch (e) {} return v || 0; }
    function qs(id) { return document.getElementById(id); }
    function authed() {
      var a = qs("auth-screen");
      if (!a) return false;
      if (a.classList.contains("hidden")) return true;
      try { if (getComputedStyle(a).display === "none") return true; } catch (e) {}
      return false;
    }

    // ── manuel giriste email+sifre yakala (uygulamanin handler'indan ONCE) ──
    document.addEventListener("submit", function (ev) {
      var f = ev.target;
      if (!f || f.id !== "auth-form") return;
      var em = qs("auth-email"), pw = qs("auth-password");
      if (em && pw && em.value && pw.value) pendCreds = { email: em.value.trim(), password: pw.value };
    }, true);

    // ── basarili giris sonrasi: kayitliysa creds'i sessizce tazele; degilse enroll teklif et ──
    function onAuthedMaybe() {
      if (!pendCreds || !authed()) return;
      var creds = pendCreds; pendCreds = null;
      touch();
      if (enrolled) {
        // sifre degismis olabilir -> Keychain'i sessizce guncelle (Face ID istemeden)
        try { BIO.setCredentials({ username: creds.email, password: creds.password, server: SERVER }).catch(function () {}); } catch (e) {}
        return;
      }
      if (enrolling) return;
      enrolling = true;
      BIO.isAvailable().then(function (res) {
        if (!res || !res.isAvailable) { enrolling = false; return; }
        offerEnroll(function (yes) {
          if (!yes) { enrolling = false; return; }
          BIO.verifyIdentity({ reason: "Face ID'yi etkinlestir", title: "Derive Intelligence", description: "Hizli giris icin Face ID" })
            .then(function () { return BIO.setCredentials({ username: creds.email, password: creds.password, server: SERVER }); })
            .then(function () { enrolled = true; try { localStorage.setItem(FLAG, "1"); } catch (e) {} touch(); toast("Face ID etkinlestirildi"); enrolling = false; })
            .catch(function () { enrolling = false; });
        });
      }).catch(function () { enrolling = false; });
    }

    var asc = qs("auth-screen");
    if (asc) {
      try { new MutationObserver(function () { onAuthedMaybe(); }).observe(asc, { attributes: true, attributeFilter: ["class", "style"] }); } catch (e) {}
    }

    // ── login formunu Keychain creds ile doldur + gonder, basari bekle ──
    function formLogin(c) {
      return new Promise(function (resolve) {
        var em = qs("auth-email"), pw = qs("auth-password"), f = qs("auth-form");
        if (!em || !pw || !f || !c || !c.username) { resolve(false); return; }
        pendCreds = null; // otomatik girisi enroll-teklifi olarak sayma
        em.value = c.username; pw.value = c.password;
        if (f.requestSubmit) f.requestSubmit(); else f.dispatchEvent(new Event("submit", { cancelable: true, bubbles: true }));
        var t = 0, iv = setInterval(function () { t += 200; if (authed() || t > 15000) { clearInterval(iv); resolve(authed()); } }, 200);
      });
    }

    function logoutReload() {
      try { localStorage.removeItem("currentPlatformUser"); } catch (e) {}
      fetch("/api/auth/logout", { method: "POST", credentials: "same-origin" })
        .catch(function () {})
        .then(function () { location.reload(); });
    }
    function disableFaceId() {
      try { localStorage.removeItem(FLAG); } catch (e) {}
      enrolled = false;
      try { BIO.deleteCredentials({ server: SERVER }).catch(function () {}); } catch (e) {}
    }

    // ── KILIT EKRANI ──
    function lock(needLogin) {
      if (gating) return;
      gating = true;
      var ov = buildLock();
      var statusEl = ov.querySelector("[data-st]");
      var btns = ov.querySelector("[data-bt]");
      function done() { try { ov.parentNode && ov.parentNode.removeChild(ov); } catch (e) {} gating = false; touch(); }
      function showButtons(msg) {
        if (statusEl) statusEl.textContent = msg || "Face ID ile acilamadi.";
        if (btns) btns.style.display = "flex";
      }
      function attempt() {
        if (btns) btns.style.display = "none";
        if (statusEl) statusEl.textContent = "Face ID ile aciliyor…";
        BIO.isAvailable().then(function (res) {
          if (!res || !res.isAvailable) { showButtons("Bu cihazda Face ID yok."); return; }
          BIO.verifyIdentity({ reason: "Derive girisini ac", title: "Derive Intelligence" })
            .then(function () {
              if (needLogin && !authed()) {
                if (statusEl) statusEl.textContent = "Giris yapiliyor…";
                return BIO.getCredentials({ server: SERVER }).then(function (c) { return formLogin(c); }).then(function (ok) {
                  if (ok) done(); else showButtons("Kayitli giris basarisiz. Sifre ile deneyin.");
                });
              }
              done();
            })
            .catch(function () { showButtons("Face ID dogrulanamadi."); });
        }).catch(function () { showButtons("Face ID kullanilamiyor."); });
      }
      // butonlar
      ov.querySelector("[data-retry]").addEventListener("click", attempt);
      ov.querySelector("[data-pw]").addEventListener("click", function () { logoutReload(); });
      ov.querySelector("[data-off]").addEventListener("click", function () { disableFaceId(); done(); });
      attempt();
    }

    // ── UI kuruculari (koyu tema, splash ile uyumlu) ──
    function buildLock() {
      var ov = document.createElement("div");
      ov.setAttribute("data-faceid-lock", "1");
      ov.style.cssText = "position:fixed;inset:0;z-index:2147483000;background:#0f172a;color:#e2e8f0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px;padding:24px;padding-top:calc(24px + env(safe-area-inset-top,0px));font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;text-align:center";
      ov.innerHTML =
        '<div style="font-size:22px;font-weight:800;letter-spacing:.2px">Derive <span style="color:#38bdf8">Intelligence</span></div>' +
        '<div style="font-size:44px;line-height:1">🔒</div>' +
        '<div data-st style="font-size:14px;color:#94a3b8;min-height:20px">Face ID ile aciliyor…</div>' +
        '<div data-bt style="display:none;flex-direction:column;gap:10px;width:100%;max-width:280px;margin-top:6px">' +
          '<button data-retry style="width:100%;padding:13px;border:0;border-radius:12px;background:#38bdf8;color:#0f172a;font-size:15px;font-weight:700;cursor:pointer">🔓 Face ID ile ac</button>' +
          '<button data-pw style="width:100%;padding:13px;border:1px solid #334155;border-radius:12px;background:transparent;color:#e2e8f0;font-size:15px;font-weight:600;cursor:pointer">Sifre ile gir</button>' +
          '<button data-off style="width:100%;padding:8px;border:0;border-radius:12px;background:transparent;color:#64748b;font-size:12px;cursor:pointer">Face ID\'yi kapat</button>' +
        '</div>';
      (document.body || document.documentElement).appendChild(ov);
      return ov;
    }

    function offerEnroll(cb) {
      var back = document.createElement("div");
      back.style.cssText = "position:fixed;inset:0;z-index:2147483000;background:rgba(2,6,23,.6);display:flex;align-items:flex-end;justify-content:center;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif";
      var sheet = document.createElement("div");
      sheet.style.cssText = "background:#0f172a;color:#e2e8f0;width:100%;max-width:520px;border-radius:20px 20px 0 0;padding:22px 20px calc(22px + env(safe-area-inset-bottom,0px));text-align:center;box-shadow:0 -8px 40px rgba(0,0,0,.4)";
      sheet.innerHTML =
        '<div style="font-size:40px;line-height:1;margin-bottom:8px">😊</div>' +
        '<div style="font-size:18px;font-weight:800;margin-bottom:6px">Face ID ile hizli giris</div>' +
        '<div style="font-size:13.5px;color:#94a3b8;line-height:1.5;margin-bottom:18px">Bir dahaki acilista sifre yazmadan, Face ID ile giris yapabilirsin. Bilgilerin cihazin guvenli kasasinda (Keychain) saklanir.</div>' +
        '<button data-yes style="width:100%;padding:14px;border:0;border-radius:13px;background:#38bdf8;color:#0f172a;font-size:15px;font-weight:800;cursor:pointer;margin-bottom:10px">Etkinlestir</button>' +
        '<button data-no style="width:100%;padding:12px;border:0;border-radius:13px;background:transparent;color:#94a3b8;font-size:14px;cursor:pointer">Simdi degil</button>';
      back.appendChild(sheet);
      (document.body || document.documentElement).appendChild(back);
      function close(v) { try { back.parentNode.removeChild(back); } catch (e) {} cb(v); }
      sheet.querySelector("[data-yes]").addEventListener("click", function () { close(true); });
      sheet.querySelector("[data-no]").addEventListener("click", function () { close(false); });
      back.addEventListener("click", function (e) { if (e.target === back) close(false); });
    }

    function toast(msg) {
      var t = document.createElement("div");
      t.style.cssText = "position:fixed;left:50%;bottom:calc(40px + env(safe-area-inset-bottom,0px));transform:translateX(-50%);z-index:2147483001;background:#0f172a;color:#fff;padding:11px 18px;border-radius:12px;font-size:13px;box-shadow:0 6px 18px rgba(0,0,0,.35);font-family:-apple-system,sans-serif";
      t.textContent = msg;
      (document.body || document.documentElement).appendChild(t);
      setTimeout(function () { try { t.parentNode.removeChild(t); } catch (e) {} }, 2200);
    }

    // ── COLD LAUNCH: kayitliysa hemen (senkron) kilit ekranini goster, sonra Face ID ──
    if (enrolled) {
      // opak overlay app'i altta render etse bile ortur; needLogin=true -> oturum dusmusse Keychain ile gir
      lock(true);
    }

    // ── IDLE: arka plandan donuste 3 dk+ gectiyse tekrar kilitle ──
    document.addEventListener("visibilitychange", function () {
      if (document.visibilityState === "visible") {
        if (enrolled && !gating && (now() - lastActive() > IDLE_MS)) lock(false);
      } else {
        touch();
      }
    });
    // aktiflik damgasi
    ["click", "keydown", "touchstart"].forEach(function (ev) { document.addEventListener(ev, touch, { passive: true }); });
  } catch (e) { /* Face ID modulu asla app'i kirmamali */ }
})();


// ═══ AUTO_LOGOUT_V1 — rol-bazli oto cikis (guvenlik) ══════════════════════════
//   Yonetici/mudur (web): 30 dk bosta -> uyari -> cikis. Herkes: mutlak sure
//   (yonetici/mudur 24s, saha temsilcisi 7g). Native app'te bosta-cikis YOK
//   (cihaz kilidi devrede); yalniz mutlak sure. Sabitler asagidan degistirilebilir.
//   Oturum yoksa (login ekrani) hicbir sey yapmaz.
(function(){
  if (typeof window === "undefined" || window.__autoLogoutV1) return;
  window.__autoLogoutV1 = true;

  var IDLE_MIN_STAFF  = 30;   // dk — yonetici/mudur bosta (yalniz web)
  var ABS_HOURS_STAFF = 24;   // saat — yonetici/mudur mutlak
  var ABS_HOURS_REP   = 168;  // saat — saha temsilcisi mutlak (7 gun)
  var WARN_SEC        = 60;   // bosta uyari geri sayimi (sn)

  var CAP = window.Capacitor;
  var isNative = !!(CAP && CAP.isNativePlatform && CAP.isNativePlatform());

  function me(){ try { return JSON.parse(localStorage.getItem("currentPlatformUser")||"null"); } catch(e){ return null; } }
  function policy(){
    var m = me(); if (!m) return null;
    var subs = m.subscriptions || [];
    var admin = m.tenantRole === "platform_owner" || subs.some(function(s){ return s.moduleRole==="admin"; });
    var manager = subs.some(function(s){ return s.moduleRole==="manager"; });
    var staff = admin || manager;
    return { idleMs: (!isNative && staff) ? IDLE_MIN_STAFF*60000 : 0,
             absMs: (staff ? ABS_HOURS_STAFF : ABS_HOURS_REP) * 3600000 };
  }

  var last = Date.now(), warnEl = null, warnType = null, busy = false;
  function bump(){ var n = Date.now(); if (n - last > 1500) last = n; if (warnEl && warnType === "idle") closeWarn(); }
  ["pointerdown","keydown","touchstart","scroll","mousemove"].forEach(function(ev){
    window.addEventListener(ev, bump, { passive: true });
  });

  function doLogout(){
    if (busy) return; busy = true;
    try { var tok = localStorage.getItem("platformSessionToken");
      fetch("/api/auth/logout", { method:"POST", credentials:"include", headers: tok ? { Authorization:"Bearer "+tok } : {} }); } catch(e){}
    ["krbCurrentUserEmail","krbSession","currentPlatformUser","platformSessionToken","krbLoginAt"].forEach(function(k){ try{ localStorage.removeItem(k); }catch(e){} });
    setTimeout(function(){ location.href = "/?app=1"; }, 300);
  }

  function closeWarn(){ if (warnEl){ if (warnEl._t) clearInterval(warnEl._t); if (warnEl._to) clearTimeout(warnEl._to); warnEl.remove(); warnEl = null; warnType = null; } }
  function shell(inner){
    var el = document.createElement("div");
    el.style.cssText = "position:fixed;inset:0;z-index:100001;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;padding:24px";
    el.innerHTML = '<div style="background:#fff;border-radius:16px;max-width:340px;width:100%;padding:22px;box-shadow:0 20px 60px rgba(0,0,0,.45);text-align:center">'+inner+'</div>';
    document.body.appendChild(el); return el;
  }
  function idleWarn(){
    warnType = "idle";
    warnEl = shell('<div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:8px">Oturum zaman asimi</div>'
      +'<div style="font-size:13px;color:#475569;line-height:1.5;margin-bottom:16px">Bir suredir islem yapmadiniz. Guvenlik icin <b><span id="alo-say">'+WARN_SEC+'</span> sn</b> icinde cikis yapilacak.</div>'
      +'<button id="alo-stay" style="width:100%;padding:12px;border:none;background:#0284c7;color:#fff;border-radius:10px;font-size:14px;font-weight:700;font-family:inherit;cursor:pointer">Oturumu acik tut</button>');
    var s = WARN_SEC;
    warnEl._t = setInterval(function(){ s--; var e=document.getElementById("alo-say"); if(e) e.textContent=s; if(s<=0){ closeWarn(); doLogout(); } }, 1000);
    warnEl.querySelector("#alo-stay").addEventListener("click", function(){ last = Date.now(); closeWarn(); });
  }
  function absWarn(){
    warnType = "abs";
    warnEl = shell('<div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:8px">Oturum suresi doldu</div>'
      +'<div style="font-size:13px;color:#475569;line-height:1.5;margin-bottom:16px">Guvenlik icin oturum suresi doldu. Yeniden giris yapmaniz gerekiyor.</div>'
      +'<button id="alo-ok" style="width:100%;padding:12px;border:none;background:#0284c7;color:#fff;border-radius:10px;font-size:14px;font-weight:700;font-family:inherit;cursor:pointer">Yeniden giris</button>');
    warnEl._to = setTimeout(doLogout, 12000);
    warnEl.querySelector("#alo-ok").addEventListener("click", doLogout);
  }

  setInterval(function(){
    if (busy) return;
    var m = me();
    if (!m){ if (warnEl) closeWarn(); try{ localStorage.removeItem("krbLoginAt"); }catch(e){} return; }
    var p = policy(); if (!p) return;
    var loginAt = parseInt(localStorage.getItem("krbLoginAt")||"0", 10);
    if (!loginAt){ loginAt = Date.now(); try{ localStorage.setItem("krbLoginAt", String(loginAt)); }catch(e){} }
    var now = Date.now();
    if (p.absMs && (now - loginAt) >= p.absMs){ if (warnType !== "abs"){ closeWarn(); absWarn(); } return; }
    if (p.idleMs){ var idle = now - last; if (idle >= p.idleMs - WARN_SEC*1000){ if (!warnEl) idleWarn(); } }
  }, 5000);
})();

