import { TaskFactory as TaskFactory$1 } from './task-factory.js';

function taskFromPropertyDescriptor(target, key, descriptor, params = [], factoryClass = TaskFactory$1) {
  let {
    initializer,
    get,
    value
  } = descriptor;
  let taskFn;
  if (initializer) {
    taskFn = initializer.call(undefined);
  } else if (get) {
    taskFn = get.call(undefined);
  } else if (value) {
    taskFn = value;
  }
  taskFn.displayName = `${key} (task)`;
  let tasks = new WeakMap();
  let options = params[0] || {};
  let factory = new factoryClass(key, taskFn, options);
  factory._setupEmberKVO(target);
  return {
    get() {
      let task = tasks.get(this);
      if (!task) {
        task = factory.createTask(this);
        tasks.set(this, task);
      }
      return task;
    }
  };
}
function taskGroupPropertyDescriptor(_target, key, _descriptor, params = [], factoryClass = TaskFactory$1) {
  let taskGroups = new WeakMap();
  let options = params[0] || {};
  let factory = new factoryClass(key, null, options);
  return {
    get() {
      let task = taskGroups.get(this);
      if (!task) {
        task = factory.createTaskGroup(this);
        taskGroups.set(this, task);
      }
      return task;
    }
  };
}

// Cribbed from @ember-decorators/utils
function isFieldDescriptor(possibleDesc) {
  let [target, key, desc] = possibleDesc;
  return possibleDesc.length === 3 && typeof target === 'object' && target !== null && typeof key === 'string' && (typeof desc === 'object' && desc !== null && 'enumerable' in desc && 'configurable' in desc || desc === undefined) // TS compatibility ???
  ;
}
function decoratorWithParams(descriptorFn) {
  return function (...params) {
    if (isFieldDescriptor(params)) {
      return descriptorFn(...params);
    } else {
      return (...desc) => descriptorFn(...desc, params);
    }
  };
}
function createDecorator(fn, baseOptions = {}, factoryClass = TaskFactory$1) {
  return decoratorWithParams((target, key, descriptor, [userOptions] = []) => {
    let mergedOptions = Object.assign({}, {
      ...baseOptions,
      ...userOptions
    });
    return fn(target, key, descriptor, [mergedOptions], factoryClass);
  });
}
function createTaskDecorator(baseOptions = {}, factoryClass = TaskFactory$1) {
  return createDecorator(taskFromPropertyDescriptor, baseOptions, factoryClass);
}
function createTaskGroupDecorator(baseOptions = {}, factoryClass = TaskFactory$1) {
  return createDecorator(taskGroupPropertyDescriptor, baseOptions, factoryClass);
}
const lastValue = decoratorWithParams((_target, _key, descriptor, [taskName] = []) => {
  const {
    initializer
  } = descriptor;
  delete descriptor.initializer;
  return {
    get() {
      let lastInstance = this[taskName].lastSuccessful;
      if (lastInstance) {
        return lastInstance.value;
      }
      if (initializer) {
        return initializer.call(this);
      }
      return undefined;
    }
  };
});

export { createTaskDecorator, createTaskGroupDecorator, decoratorWithParams, lastValue };
//# sourceMappingURL=task-decorators.js.map
