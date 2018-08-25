/**
 * TaskCheckResults.js
 *
 * @description :: A model definition.  Represents a database table/collection/etc.
 * @docs        :: https://sailsjs.com/docs/concepts/models-and-orm/models
 */

module.exports = {
  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  tableName: 'task_check_results',
  autoCreatedAt: false,
  autoUpdatedAt: false,
  attributes: {
    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },

    task_check_id: {
      columnName: 'task_check_id',
      type: 'integer',
      required: true
    },

    taskCheck: {
      collection: 'taskChecks',
      via: 'taskCheckResults'
    },

    result_id: {
      columnName: 'result_id',
      type: 'integer',
      required: true
    },

    taskCheckResult: {
      collection: 'parameters',
      via: 'id'
    },

    reason: {
      columnName: 'reason',
      type: 'string'
    },

    taking_action_on: {
      columnName: 'taking_action_on',
      type: 'datetime',
      required: true
    },

    created_at: {
      type: 'datetime'
    },
    updated_at: {
      type: 'datetime'
    },
    updated_by_user: {
      type: 'integer',
      columnName: 'updated_by_user_id',
      required: true
    }

  },

};

