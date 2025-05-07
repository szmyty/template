import { createStore, applyMiddleware, combineReducers, compose } from 'redux';
import {thunk} from 'redux-thunk';
import keplerGlReducer from '@kepler.gl/reducers';

const reducers = combineReducers({
  keplerGl: keplerGlReducer,
});

const store = createStore(reducers, compose(applyMiddleware(thunk)));

export default store;
