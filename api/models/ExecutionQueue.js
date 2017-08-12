/**
 * ExecutionQueue.js
 *
 * @description :: TODO: You might write a short summary of how this model works and what it represents here.
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {

  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  tableName: 'execution_queue',
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
      type: 'integer',
      required: true
    },
    executed: {
      type: 'boolean',
      required: true
    },
    next_execution: {
      type: 'datetime'
    },
    created_at: {
      type: 'datetime'
    }
  }
};

