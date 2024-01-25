import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import SlaAPI from '../../api/sla';
import AnalyticsHelper from '../../helper/AnalyticsHelper';
import { SLA_EVENTS } from '../../helper/AnalyticsHelper/events';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isDeleting: false,
  },
};

export const getters = {
  getSLA(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getSLA({ commit }) {
    commit(types.SET_SLA_UI_FLAG, { isFetching: true });
    try {
      const response = await SlaAPI.get(true);
      const sortedSLA = response.data.payload.sort((a, b) =>
        a.title.localeCompare(b.title)
      );
      commit(types.SET_SLA, sortedSLA);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_SLA_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createSLA({ commit }, cannedObj) {
    commit(types.SET_SLA_UI_FLAG, { isCreating: true });
    try {
      const response = await SlaAPI.create(cannedObj);
      AnalyticsHelper.track(SLA_EVENTS.CREATE);
      commit(types.ADD_SLA, response.data);
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_SLA_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateSLA({ commit }, { id, ...updateObj }) {
    commit(types.SET_SLA_UI_FLAG, { isUpdating: true });
    try {
      const response = await SlaAPI.update(id, updateObj);
      AnalyticsHelper.track(SLA_EVENTS.UPDATE);
      commit(types.EDIT_SLA, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SLA_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteSLA({ commit }, id) {
    commit(types.SET_SLA_UI_FLAG, { isDeleting: true });
    try {
      await SlaAPI.delete(id);
      AnalyticsHelper.track(SLA_EVENTS.DELETED);
      commit(types.DELETE_SLA, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SLA_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_SLA_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_SLA]: MutationHelpers.set,
  [types.ADD_SLA]: MutationHelpers.create,
  [types.EDIT_SLA]: MutationHelpers.update,
  [types.DELETE_SLA]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};