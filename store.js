const state = {
  session: {
    currentRole: null,
    currentUser: null,
    currentUserEmail: null,
    currentSessionToken: null,
    activeViewId: null,
    activeAssessmentWorkspaceTab: null,
    activeQuestionBankRole: null,
    activeContextLanguage: null,
    selectedFindingId: null,
    shouldOpenAppShell: false
  },
  platform: {
    projects: [],
    activeProjectId: null,
    users: {},
    metrics: null,
    commandCenterError: null,
    classificationFilter: null
  },
  assessment: {
    activeAssessmentId: null,
    blueprint: null,
    participants: [],
    sessions: [],
    findings: [],
    evidence: [],
    clusters: [],
    recommendations: [],
    roadmapItems: [],
    coverage: null,
    progressMemory: null,
    managerCommandCenterState: null,
    managerCommandCenterError: null,
    participantRoleFilter: null,
    participantGroupFilter: null,
    participantStatusFilter: null,
    participantAccessLinks: {},
    uploadPreview: null,
    importSummary: null,
    invitationSummary: null,
    invitationPreview: null,
    reminderSummary: null,
    reminderPreview: null
  },
  executive: {
    report: null,
    reportToggles: {},
    progressSnapshot: null,
    ownerFilterState: {
      stakeholderGroup: null,
      stakeholderRole: null,
      heatmapDomain: null,
      heatmapGroup: null,
      heatmapMinPriority: null,
      onlyMisalignment: false,
      onlyHighConfidence: false,
      selectedHeatmapCellKey: null
    }
  },
  consultant: {
    commandCenterState: null,
    commandCenterError: null
  },
  operations: {
    krbOperationsState: {},
    section: null,
    loading: false,
    error: null,
    lastRefreshed: null
  },
  framework: {
    questionBanks: {},
    roles: []
  }
};

const subscribers = {};

export function getState() {
  return state;
}

export function getSlice(slice) {
  return state[slice];
}

export function setState(slice, key, value) {
  if (!state[slice]) state[slice] = {};
  state[slice][key] = value;
  (subscribers[slice] || []).forEach((callback) => callback(state[slice]));
}

export function mergeState(slice, partial) {
  if (!state[slice]) state[slice] = {};
  Object.assign(state[slice], partial);
  (subscribers[slice] || []).forEach((callback) => callback(state[slice]));
}

export function subscribe(slice, callback) {
  if (!subscribers[slice]) subscribers[slice] = [];
  subscribers[slice].push(callback);
  return () => {
    subscribers[slice] = (subscribers[slice] || []).filter((item) => item !== callback);
  };
}
