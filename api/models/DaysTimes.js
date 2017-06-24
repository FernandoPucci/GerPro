/**
 * DaysTimes.js
 *
 * @description :: Representative model from DaysTimes table
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {

  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  tableName: 'days_times',
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
      required: true,
      model: 'TaskChecks',
      unique: true
    },
    hour: {
      type: 'numeric',
      required: true
    },
    minute: {
      type: 'numeric',
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
    // },

    // taskchecks: {     
    //   model: 'task_checks'
    // }
  }
};

