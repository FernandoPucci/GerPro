/**
 * Auditions.js
 *
 * @description :: Representative model from Auditions table
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 * 
 * 
 */

module.exports = {
  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  autoCreatedAt: false,
  autoUpdatedAt: false,
  attributes: {

    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },

    tableName: {
      type: 'string',
      columnName: 'table_name',
      required: true
    },
    operation: {
      type: 'string',
      columnName: 'operation',
      required: true
    },
    primaryKey: {
      type: 'string',
      columnName: 'primary_key',
      required: true
    },
    old_values: {
      type: 'string',
      columnName: 'old_values'
    },
    createdAt: {
      type: 'datetime',
      columnName: 'created_at',
      required: true
    },
    updatedByUser: {
      type: 'integer',
      columnName: 'updated_by_user_id'
    }
  }
};

