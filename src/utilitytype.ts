import type { StoreApi, UseBoundStore } from 'zustand';
import { useShallow } from 'zustand/react/shallow';

export type Concat<T extends string[]> = T extends [infer F extends string, ...infer R extends string[]] ? `${F}${Concat<R>}` : '';

export type PrefixCapitalize<P extends string, K extends string> = Concat<[P, Capitalize<K>]>;

interface HookMap { [index: string]: unknown }

type FilterState<S> = S extends { getState: () => infer T } ? keyof Omit<T, `_${string}`> : never;

// const name = state.use.name()
type WithScopeUse<S> = S extends { getState: () => infer T } ? S & { use: { [K in FilterState<S>]: () => T[K] } } : never;
export function createScopeUse<S extends UseBoundStore<StoreApi<object>>>(_store: S) {
  const store = _store as WithScopeUse<typeof _store>;
  const use = {} as HookMap;
  for (const key of Object.keys(store.getState())) {
    if (use[key]) {
      throw new Error(`exists same key [${key}] in ${store}`);
    }
    use[key] = () => store(s => s[key as keyof typeof s]);
  }
  store.use = use;
  return store;
}

const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

// const name = state.useName()
type PrefixUse<K extends string> = PrefixCapitalize<'use', K>;
type WithUse<S> = S extends { getState: () => infer T } ? S & { [K in FilterState<S> as PrefixUse<K>]: () => T[K] } : never;

export function createUse<S extends UseBoundStore<StoreApi<object>>>(_store: S) {
  const store = _store as WithUse<S>;
  const obj = store as unknown as HookMap;
  for (const key of Object.keys(store.getState())) {
    const useKey = `use${capitalize(key)}`;
    if (obj[useKey]) {
      throw new Error(`exists same key [${useKey}] in ${store}`);
    }
    obj[useKey] = () => store(s => s[key as keyof typeof s]);
  }
  return store;
}

// state.setName(newName)
type PrefixSet<K extends string> = PrefixCapitalize<'set', K>;
type WithSet<S> = S extends { getState: () => infer T } ? S & {
  [K in FilterState<S> as PrefixSet<K>]: (value: T[K] | ((oldValue: T[K]) => T[K])) => void;
}
  : never;

export function createSet<S extends UseBoundStore<StoreApi<object>>>(_store: S) {
  const store = _store as WithSet<S>;
  const obj = store as unknown as HookMap;
  for (const key of Object.keys(store.getState())) {
    const setKey = `set${capitalize(key)}`;
    if (obj[setKey]) {
      throw new Error(`exists same key [${setKey}] in ${store}`);
    }
    obj[setKey] = (val: unknown) => {
      if (typeof val === 'function') {
        store.setState((state) => {
          return Object.fromEntries([[key, val((state as any)[key])]]);
        });
      }
      else {
        store.setState(Object.fromEntries([[key, val]]));
      }
    };
  }
  return store;
}

// const [name, age] = useSelector(state, ['name', 'age'] as const)
// ! as const PLZ

export function useSelector<S, K extends readonly (keyof S)[]>(store: UseBoundStore<StoreApi<S>>, keys: K) {
  return store(useShallow(state => keys.map(key => state[key]))) as unknown as {
    [index in keyof K]: S[K[index]];
  };
}

export function injectAction<S extends UseBoundStore<StoreApi<object>>, A extends object>(_store: S, actions: A) {
  const store = _store as S & A;

  for (const key of Object.keys(actions)) {
    const map = store as unknown as HookMap;
    if (map[key]) {
      throw new Error(`The key ${key} already exists in store`);
    }
    map[key] = (actions as HookMap)[key];
  }
  return store;
}
