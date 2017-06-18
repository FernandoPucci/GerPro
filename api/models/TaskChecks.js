/**
 * TaskChecks.js
 *
 * @description :: Representative model from Auditions table task_checks
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {
  //connection: 'db_server',
  // //configurations to disale UpdateAt and CreatedAt Waterline Columns
  autoCreatedAt: false,
  autoUpdatedAt: false,
  
  attributes: {
    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },
    name: {
      type: 'string',
      columnName: 'name',
      required: true
    },
    description: {
      type: 'text',
      columnName: 'description'
    },
    place: {
      type: 'integer',
      columnName: 'place_id',
      required: true
    },
    user_checker: {
      type: 'integer',
      columnName: 'user_checker_id',
      required: true
    },
    periodicity: {
      type: 'integer',
      columnName: 'periodicity_id',
      required: true
    },
    starts_at: {
      type: 'datetime',
      required: true
    },
    ends_at: {
      type: 'datetime',
    },
    repeatsEvery: {
      type: 'integer',
      required: true
    },
    created_at: {
      type: 'datetime',
      required: true
    },
    updated_at: {
      type: 'datetime',
      required: true
    },
    updated_by_user: {
      type: 'integer',
      columnName: 'updated_by_user_id',
      required: true
    },
    active: {
      type: 'boolean',
      columnName: 'active',
      required: true
    }


  }
};
