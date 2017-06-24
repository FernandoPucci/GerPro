/**
 * Notifications.js
 *
 * @description :: Representative model from Notifications table
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {

  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  tableName: 'notifications',
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
      model: 'TaskChecks',
      required: true
    },
    notification_type_id: {
      type: 'integer',
      required: true
    },
    pre_notify_days: {
      type: 'integer',
      defaultsTo: '0'
    },
    pre_notify_hours: {
      type: 'integer',
      defaultsTo: '0'
    },
    pre_notify_minutes: {
      type: 'integer',
      defaultsTo: '10'
    },
    notify_again_every: {
      type: 'integer',
      defaultsTo: '0'
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

