/**
 * WeeksDays.js
 *
 * @description :: Representative model from WeeksDays table
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {

  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  tableName: 'weeks_days',
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
    sunday: {
      type: 'boolean',
      defaultsTo: 'false'
    },
    monday: {
      type: 'boolean',
      defaultsTo: 'false'
    },
    tuesday: {
      type: 'boolean',
      defaultsTo: 'false'
    },
    wednesday: {
      type: 'boolean',
      defaultsTo: 'false'
    },
    thursday: {
      type: 'boolean',
      defaultsTo: 'false'
    },
    friday: {
      type: 'boolean',
      defaultsTo: 'false'
    },

    saturday: {
      type: 'boolean',
      defaultsTo: 'false'
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
  }
};

