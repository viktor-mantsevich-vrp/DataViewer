/**
 * Created by Администратор on 30.05.2017.
 */
public with sharing class DataViewerController {

	@RemoteAction
	public static String getSObjectNames() {
		Map<String, Schema.SObjectType> sObjects = Schema.getGlobalDescribe();
		Map<String, String> sObjectNames = new Map<String, String>();
		for (String apiName : sObjects.keySet()) {
			Schema.SObjectType sObj = sObjects.get(apiName);
			String sObjectLabel = sObj.getDescribe().getLabel();
			sObjectNames.put(apiName, sObjectLabel);
		}
		return JSON.serialize(sObjectNames);
	}

	@RemoteAction
	public static String getFields(String sObjectName) {
		Map<String, Schema.SObjectType> sObjects = Schema.getGlobalDescribe();
		Map<String,Schema.SObjectField> fieldsOfObj = sObjects.get(sObjectName).getDescribe().fields.getMap();
		Map<String, Map<String, String>> fieldsData = new Map<String, Map<String, String>>();
		for (String apiName : fieldsOfObj.keySet()) {
			Schema.DescribeFieldResult describeField = fieldsOfObj.get(apiName).getDescribe();
			String fieldLabel = describeField.getLabel();
			Boolean isEditableField = describeField.isUpdateable();
			Boolean isCreateableField = describeField.isCreateable();
			Boolean isCustomField = describeField.isCustom();
			Schema.DisplayType typeField = describeField.getType();
			fieldsData.put(
					apiName,
					new Map<String, String>{
						'label' => fieldLabel,
						'isEditable' => String.valueOf(isEditableField),
						'isCreateable' => String.valueOf(isCreateableField),
						'isCustom' => String.valueOf(isCustomField),
						'type' => typeField.name()
					}
			);
		}
		return JSON.serialize(fieldsData);
	}

	@RemoteAction
	public static String getData(String objName, String fieldsStr) {
		//Set<String> fieldsSet = (Set<String>)JSON.deserialize(fieldsStr,Set<String>.class);
		Set<String> fieldsSet = new Set<String>();
		for(Object fieldObj : (List<Object>)JSON.deserializeUntyped(fieldsStr)){
			fieldsSet.add(String.valueOf(fieldObj));
		}
		QueryBuilder builderForDataViewer = new QueryBuilder(objName, fieldsSet);
		//queryForDataViewer.queryFields = fieldsSet;
		String queryStr = builderForDataViewer.buildQueryString();
		List<sObject> sObjects = Database.query(queryStr);
		System.debug('sObjects:');
		System.debug(sObjects);
		return JSON.serialize(sObjects);
	}

	//DML methods
	@RemoteAction
	public static String updateRow(String objInJSON){
		Map<String, Object> objMap = (Map<String, Object>) JSON.deserializeUntyped(objInJSON);
		String objJsonDrunk = JSON.serialize(objMap);
		SObject obj = (SObject)JSON.deserialize(objJsonDrunk, Sobject.class);
		Database.SaveResult response = updateWithoutSharing(obj);
		return JSON.serialize(response);
	}

	private static Database.SaveResult updateWithoutSharing(sObject obj/*, Schema.DescribeFieldResult[] fields*/) {
		/*FLSAccessControllerWithSharing acws = new FLSAccessControllerWithSharing();
		String notUpdateableFLS =
			((UserInfo.getUserType() == 'Guest') && !obj.getSObjectType().getDescribe().isCustom()) ?
				acws.hasNotCreateableFLS(fields) :
				acws.hasNotUpdateableFLS(fields);
		if (notUpdateableFLS != NULL) {
			throw new DatabaseWorkException();
		}*/
		return Database.update(obj);
	}

	private class QueryBuilder {
		private String objName;
		private Set<String> fieldNames;
		private String qString;

		public QueryBuilder(String objName, Set<String> fieldNames){
			this.objName = objName;
			this.fieldNames = fieldNames;
		}

		public String queryString {
			get {
				if (qString == null){
					qString = buildQueryString();
				}
				return qString;
			}
		}

		private String buildQueryString () {
			String queryStr = 'SELECT {0} FROM {1}';
			String fieldNamesString = String.join(new List<String>(fieldNames), ',');
			return String.format(queryStr, new String[]{fieldNamesString, objName});
		}
	}

	private with sharing class FLSAccessControllerWithSharing {
		public String hasNotCreateableFLS(Schema.DescribeFieldResult[] fields) {
			String result = NULL;
			for (Schema.DescribeFieldResult field : fields) {
				Boolean isCreateable = field.isCreateable();
				if (!isCreateable) {
					result = field.getName();
					break;
				}
			}
			return result;
		}
		public String hasNotUpdateableFLS(Schema.DescribeFieldResult[] fields) {
			String result = NULL;
			for (Schema.DescribeFieldResult field : fields) {
				// For Master-Detail fields check for Creatable instead of Updateable access
				Boolean isUpdateable = (field.getRelationshipOrder() != NULL) ? field.isCreateable() : field.isUpdateable();
				if (!isUpdateable) {
					result = field.getName();
					break;
				}
			}
			return result;
		}
		public Boolean isObjectCreateable(sObject obj) {
			return obj.getSObjectType().getDescribe().isCreateable();
		}
		public Boolean isObjectsCreateable(sObject[] objs) {
			return objs.getSObjectType().getDescribe().isCreateable();
		}
		public Boolean isObjectDeletable(sObject obj) {
			return obj.getSObjectType().getDescribe().isDeletable();
		}
		public Boolean isObjectsDeletable(sObject[] objs) {
			return objs.getSObjectType().getDescribe().isDeletable();
		}
	}

	public class DatabaseWorkException extends Exception{}
}