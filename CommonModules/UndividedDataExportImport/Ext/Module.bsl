////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

Function TypesDependenciesOnReplacingRefs() Export
	
	Return ExportImportUndividedDataReUse.DependenciesUndividedMetadataObjects();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// handlers of the service events

// Fills out the array of types for which you need to use the refs annotation in the export files when exporting.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingTypesRequireAnnotationRefsOnImport(Types) Export
	
	CommonDataTypes = DataExportImportServiceEvents.GetCommonDataTypesSupportMatchingRefsOnImport();
	For Each SharedDataType IN CommonDataTypes Do
		Types.Add(SharedDataType);
	EndDo;
	
EndProcedure

// It is called on the registration of the arbitrary handlers of data export.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random export data handlers. Columns:
//    MetadataObject - MetadataObject, when exporting
//      the data of which the registered handler must be called,
//    Handler - GeneralModule, a general module in
//      which random handler of the data export implemented. Set of export procedures
//      that must be implemented in the handler, depends on
//      the set values of the following table columns,
//    Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler, 
//    BeforeExportType - Boolean, a flag showing that a handler is to be called before exporting all the infobase objects that are associated with the metadata object. If the True value is set - in the general module
//      of a handler, exported procedure
//      BeforeExportType() must be implemented, that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager,
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//        MetadataObject - MetadataObject before exporting
//          data of which the handler was called,
//        Cancel - Boolean. If in the BeforeExportType() procedure set this parameter as True - exporting
//          of objects corresponding to the current metadata object will not be executed.
//    BeforeObjectExport - Boolean, a flag showing that it is required to call a handler before exporting a particular object of the infobase. If the
//      True value is set - in the general module of a handler, exported
//      procedure BeforeObjectExport() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        ExportObjectManager - DataProcessorObject.DataExportImportInfobaseDataExportManager -
//          Manager of the current object export. See more the review to the
//          application data processor interface   
//          DataExportImportInfobaseDataExportManager. The parameter is passed only on the call of the handler procedures for which version higher than 1.0.0.1 is specified on registration, 
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeObjectExport() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before exporting of which the handler was called.
//          Value that is passed to the BeforeObjectExport() procedure as the Object parameter value can be modified within the BeforeObjectExport() processor, made changes will be shown in the object serialization of export files, but will not be recorded in the infobase 
//        Artifacts - Array(XDTOObject) - Set additional information logically
//          connected inextricably with the object but not not being his part artifacts object). Artifacts
//          should formed inside handler BeforeObjectExport() and added
//          to the array passed as parameter values Artifacts. Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem. Further
//          artifacts that are formed in the procedure BeforeObjectExport(), will
//          be available in handlers procedures of data import (see review for the procedure WhenDataImportHandlersRegistration().
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeObjectExport()- object export for which the
//           handler was called will not be executed.
//    AfterExportType() - Boolean, a flag showing that a handler is to be called after exporting all objects of the infobase that belongs to that metadata object. If the
//      True value is set - in a general module of the handler, exported procedure AfterExportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager,
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure AfterExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO, 
//        MetadataObject - MetadataObject, after exporting
//          data of which the handler was called.
//
Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = UndividedDataExportImport;
	NewHandler.BeforeDataExport = True;
	
	CommonDataTypes = DataExportImportServiceEvents.GetCommonDataTypesSupportMatchingRefsOnImport();
	
	For Each SharedDataType IN CommonDataTypes Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = SharedDataType;
		NewHandler.Handler = UndividedDataExportImport;
		NewHandler.BeforeExportType = True;
		NewHandler.AfterObjectExport = True;
		NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
		
	EndDo;
	
	ObjectsForUndividedDataControlOnExport = ExportImportUndividedDataReUse.ControlReferencesToUndividedDataInSeparatedOnExport();
	For Each ObjectForUndividedDataControlOnExport IN ObjectsForUndividedDataControlOnExport Do
		
		MetadataObject = Metadata.FindByFullName(ObjectForUndividedDataControlOnExport.Key);
		
		If CommonDataTypes.Find(MetadataObject) = Undefined Then // Otherwise a handler for the object is already registered
			
			NewHandler = HandlersTable.Add();
			NewHandler.MetadataObject = MetadataObject;
			NewHandler.Handler = UndividedDataExportImport;
			NewHandler.AfterObjectExport = True;
			NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BeforeDataExport(Container) Export
	
	Container.AdditionalProperties.Insert(
		"CommonDataRequireMatchingRefs",
		DataExportImportServiceEvents.GetCommonDataTypesSupportMatchingRefsOnImport()
	);
	
	Container.AdditionalProperties.Insert(
		"LocalCacheSeparatorsContents",
		New Map()
	);
	
EndProcedure

//It is called before exporting data type
//  See "WhenDataExportHandlerRegistration"
//
Procedure BeforeExportType(Container, Serializer, MetadataObject, Cancel) Export
	
	If Not CommonUseSTL.ThisIsReferenceData(MetadataObject) Then 
		Raise NStr("en='Replacement of references is available only in reference data';ru='Замена ссылок доступна только в ссылочных данных'");
	EndIf;
	
	ObjectManager = ServiceTechnologyIntegrationWithSSL.ObjectManagerByFullName(MetadataObject.FullName());
	NaturalKeyFields = ObjectManager.NaturalKeyFields();
	
	CheckNaturalKeyFields(MetadataObject, NaturalKeyFields);
	CheckNaturalKeysTakesPresence(MetadataObject, NaturalKeyFields);
	
EndProcedure

//It is called before
// exporting data object see "WhenDataExportHandlerRegistration"
//
Procedure AfterObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts) Export
	
	MetadataObject = Object.Metadata();
	FullMetadataObjectName = MetadataObject.FullName();
	
	FieldsForUndividedDataReferencesControl =
		ExportImportUndividedDataReUse.ControlReferencesToUndividedDataInSeparatedOnExport().Get(
			FullMetadataObjectName);
	
	If FieldsForUndividedDataReferencesControl <> Undefined Then
		UndividedDataReferencesControlOnExport(Container, Object, FieldsForUndividedDataReferencesControl);
	EndIf;
	
	If Container.AdditionalProperties.CommonDataRequireMatchingRefs.Find(MetadataObject) <> Undefined Then
		
		If Not CommonUseSTL.ThisIsReferenceData(MetadataObject) Then 
			Raise NStr("en='Substitution of references is available only in reference data';ru='Подмена ссылок доступна только в ссылочных данных'");
		EndIf;
		
		ObjectManager = ServiceTechnologyIntegrationWithSSL.ObjectManagerByFullName(FullMetadataObjectName);
		
		NaturalKeyFields = ObjectManager.NaturalKeyFields();
		
		NaturalKey = New Structure();
		For Each NaturalKeyField IN NaturalKeyFields Do
			NaturalKey.Insert(NaturalKeyField, Object[NaturalKeyField]);
		EndDo;
		
		ObjectExportManager.RequireMatchRefOnImport(Object.Ref, NaturalKey);
		
	EndIf;
	
EndProcedure

// Adds to the Handlers list update handler procedures
//  required to this subsystem.
//
// Parameters:
//   Handlers - ValueTable - see NewUpdateHandlersTable function description of InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler                  = Handlers.Add();
	Handler.Version           = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData      = True;
	Handler.Procedure        = "UndividedDataExportImport.ReferencesUseControlUndividedDataInSeparated";
	
	Handler                  = Handlers.Add();
	Handler.Version           = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData      = True;
	Handler.Procedure        = "UndividedDataExportImport.FillingControlNaturalKeyFieldsForUndividedObjects";
	
EndProcedure

Procedure ReferencesUseControlUndividedDataInSeparated() Export
	
	Try
		
		Cache = ExportImportUndividedDataReUse.ControlReferencesToUndividedDataInSeparatedOnExport();
		
	Except
		
		ErrorText = BriefErrorDescription(ErrorInfo());
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='There are errors in the structure of configuration metadata: %1';ru='Обнаружены ошибки в структуре метаданных конфигурации: %1'", Metadata.DefaultLanguage.LanguageCode),
			ErrorText
		);
		
	EndTry;
	
EndProcedure

Procedure FillingControlNaturalKeyFieldsForUndividedObjects() Export
	
	Try
		
		Cache = ExportImportUndividedDataReUse.DependenciesUndividedMetadataObjects();
		
	Except
		
		ErrorText = BriefErrorDescription(ErrorInfo());
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='There are errors in the structure of configuration metadata: %1';ru='Обнаружены ошибки в структуре метаданных конфигурации: %1'", Metadata.DefaultLanguage.LanguageCode),
			ErrorText
		);
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Checks if there are duplicates of objects natural keys.
//
// Parameters:
//  MetadataObject - MetadataObject - exported metadata object.
//  NaturalKeyFields - Array - array of rows that stores the names of natural keys.
//
Procedure CheckNaturalKeysTakesPresence(Val MetadataObject, Val NaturalKeyFields)
	
	TableName = MetadataObject.FullName();
	
	QueryText =
	"SELECT
	|	%1
	|	MAX(_Table_Catalog_First.Ref) AS Ref,
	|	COUNT(*) AS Ct
	|INTO vtTakes
	|FROM
	|	" + TableName + " AS _Table_Catalog_First
	|
	|GROUP BY
	|	%2
	|
	|HAVING
	|	COUNT(*) > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	_Table_Catalog_First.Ref AS RefOnItems
	|FROM
	|	vtTakes AS vtTakes
	|		INNER JOIN " + TableName + " AS
	|		_Table_Catalog_First BY vtDubli.Ref
	|		<> _Table_Catalog_First.Ref %3";
	
	AdditionalRequestText = "";
	FieldSampleText = "";
	FieldsGroupingText = "";
	Iteration = 1;
	For Each NaturalKeyField IN NaturalKeyFields Do 
		
		FieldSampleText = FieldSampleText + "_Table_Catalog_First.%KeyName, 
			|";
		
		AdditionalRequestText = AdditionalRequestText + "AND (_Table_Catalog_First.%KeyName = vtTakes.%KeyName) ";
		
		AdditionalRequestText = StrReplace(AdditionalRequestText, "%KeyName", NaturalKeyField);
		
		FieldSampleText = StrReplace(FieldSampleText, "%KeyName", NaturalKeyField);
		
		Iteration = Iteration + 1;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "%1", FieldSampleText);
	QueryText = StrReplace(QueryText, "%2", Mid(FieldSampleText, 1, StrLen(FieldSampleText) - 3));
	QueryText = StrReplace(QueryText, "%3", AdditionalRequestText);
	
	Query = New Query;
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	// Defining of the objects which primary keys are duplicated
	TakesTable = QueryResult.Unload();
	Iteration = 0;
	ItemList = "";
	For Each DuplicatedItem IN TakesTable Do 
		
		PunctuationMark = ?(Iteration = 0, "", "
		|");
		ItemList = ItemList + PunctuationMark + String(DuplicatedItem.RefOnItems);
		Iteration = Iteration + 1;
		If Iteration = 5 Then 
			Break;
		EndIf;
		
	EndDo;
	
	KeyNames = "";
	Iteration = 0;
	For Each NaturalKeyField IN NaturalKeyFields Do 
		
		PunctuationMark = ?(Iteration = 0, "", "
		|");
		KeyNames = KeyNames + PunctuationMark + NaturalKeyField;
		Iteration = Iteration + 1;
		
	EndDo;
	
	// Filling the warning text
	MessageText = ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
		NStr("en='Some %1 objects: %2"
"fields"
""
"are duplicated"
": %3.';ru='У некоторых объектов"
"%1:"
"%2"
"дублируются"
"поля: %3.'"),
		TableName, ItemList, KeyNames);
	
	Raise MessageText;
	
EndProcedure

// Check the natural keys of metadata object.
//
// Parameters:
//  MetadataObject - MetadataObject - exported metadata object.
//  NaturalKeyFields - Array - array of rows that stores the names of natural keys.
//
Procedure CheckNaturalKeyFields(Val MetadataObject, Val NaturalKeyFields)
	
	If NaturalKeyFields = Undefined Or NaturalKeyFields.Count() = 0 Then
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='For %1 data type natural keys for references replacement are not specified."
"Check handler WhenDetermineTypesRequireImportInLocalVersion.';ru='Для типа данных %1 не указаны естественные ключи для замены ссылок."
"Проверьте обработчик ПриОпределенииТиповТребующихЗагрузкиВЛокальнуюВерсию.'"),
			MetadataObject.FullName());
		
	EndIf;
	
EndProcedure

Procedure UndividedDataReferencesControlOnExport(Container, Object, FieldsForUndividedDataReferencesControl)
	
	MetadataObject = Object.Metadata();
	FullMetadataObjectName = MetadataObject.FullName();
	ObjectNameStructure = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullMetadataObjectName, ".");
	
	For Each FieldForUndividedDataReferencesControl IN FieldsForUndividedDataReferencesControl Do
		
		FieldNameStructure = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FieldForUndividedDataReferencesControl, ".");
		
		If ObjectNameStructure[0] <> FieldNameStructure[0] Or ObjectNameStructure[1] <> FieldNameStructure[1] Then
			
			Raise NStr("en='Invalid control cache of undivided data on exporting!';ru='Некорректный кэш контроля неразделенных данных при выгрузке!'");
			
		EndIf;
		
		If CommonUseSTL.ThisIsConstant(MetadataObject) Then
			
			UndividedDataReferenceControlOnExport(
				Container,
				Object.Value,
				Object,
				MetadataObject,
				FieldForUndividedDataReferencesControl);
			
		ElsIf CommonUseSTL.ThisIsReferenceData(MetadataObject) Then
			
			If FieldNameStructure[2] = "Attribute" OR FieldNameStructure[2] = "Attribute" Then // Not localized
				
				UndividedDataReferenceControlOnExport(
					Container,
					Object[FieldNameStructure[3]],
					Object,
					MetadataObject,
					FieldForUndividedDataReferencesControl
				);
				
			ElsIf FieldNameStructure[2] = "TabularSection" OR FieldNameStructure[2] = "TabularSection" Then // Not localized
				
				TabularSectionName = FieldNameStructure[3];
				
				If FieldNameStructure[4] = "Attribute" OR FieldNameStructure[4] = "Attribute" Then // Not localized
					
					AttributeName = FieldNameStructure[5];
					
					For Each TabularSectionRow IN Object[TabularSectionName] Do
						
						UndividedDataReferenceControlOnExport(
							Container,
							TabularSectionRow[AttributeName],
							Object,
							MetadataObject,
							FieldForUndividedDataReferencesControl
						);
						
					EndDo;
					
				Else
					
					Raise NStr("en='Invalid control cache of undivided data on exporting!';ru='Некорректный кэш контроля неразделенных данных при выгрузке!'");
					
				EndIf;
				
			Else
				
				Raise NStr("en='Invalid control cache of undivided data on exporting!';ru='Некорректный кэш контроля неразделенных данных при выгрузке!'");
				
			EndIf;
			
		ElsIf CommonUseSTL.ThisIsRecordSet(MetadataObject) Then
			
			If FieldNameStructure[2] = "Dimension" OR FieldNameStructure[2] = "Dimension"
					OR FieldNameStructure[2] = "Resource" OR FieldNameStructure[2] = "Resource"
					OR FieldNameStructure[2] = "Attribute" OR FieldNameStructure[2] = "Attribute" Then // Not localized
				
				For Each Record IN Object Do
					
					UndividedDataReferenceControlOnExport(
						Container,
						Record[FieldNameStructure[3]],
						Object,
						MetadataObject,
						FieldForUndividedDataReferencesControl
					);
					
				EndDo;
				
			Else
				
				Raise NStr("en='Invalid control cache of undivided data on exporting!';ru='Некорректный кэш контроля неразделенных данных при выгрузке!'");
				
			EndIf;
			
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='The %1 metadata object is not supported!';ru='Объект метаданных %1 не поддерживается!'", Metadata.DefaultLanguage.LanguageCode),
				FullMetadataObjectName
			);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure UndividedDataReferenceControlOnExport(Container, Val CheckedRefs, Val InitialObject, Val SourceMetadataObject, Val FieldName)
	
	If Not ValueIsFilled(CheckedRefs) Then
		// If the attribute value is not filled - control is not required
		Return;
	EndIf;
	
	ValueType = TypeOf(CheckedRefs);
	
	If Not CommonUse.IsReference(ValueType) Then
		// Control is required only for the reference type values
		Return;
	EndIf;
	
	MetadataObject = CheckedRefs.Metadata();
	
	If CommonUseSTL.IsEnum(MetadataObject) Then
		// The same unique identifier is used for the refs to
		// the enum items in all databases of one configuration - that is why for them
		// it is not required to execute matching refs on import
		Return;
	EndIf;
	
	If CommonUseSTL.IsReferenceDataSupportPredefinedItems(MetadataObject) Then
		If CheckedRefs.Predefined Then
			// Matching refs to predefined items is
			// executed by a separate mechanism (see general module PredefinedDataExportImport)
			Return;
		EndIf;
	EndIf;
	
	If MetadataObjectIsDividedByAtLeastOneDelimiter(MetadataObject, Container.AdditionalProperties.LocalCacheSeparatorsContents) Then
		// Separated data will be imported with saving unique identifiers
		// (for objects separated by delimiters with the separation type "Independently and jointly" all references will be generated again)
		Return;
	EndIf;
	
	If Container.AdditionalProperties.CommonDataRequireMatchingRefs.Find(MetadataObject) <> Undefined Then
		// If the developer specified for the metadata object content of natural key fields - matching
		// refs on import will be executed by the values of the natural key fields
		Return;
	EndIf;
	
	If Not CommonUse.RefExists(CheckedRefs) Then
		// the "broken" refs do not diagnose the developer's error
		// of ensuring the matching refs on import
		Return;
	EndIf;
	
	ErrorTemplate =
		NStr("en='Object metadata %1 is included in the list of objects, for which the refs mapping is not required when exporting/importing"
"data (in overridable procedure "
"DataExportImportOverridable.WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport()),"
"at that, it is not required for the object that there should be no unmapped refs when exporting."
""
"Unmapped ref is detected when exporting the object %2, which has the %3 attribute value equal to"
"a ref to the object %1, and this ref can not be mapped correctly when importing data."
"It is required to reconsider the logic of using the object %1 and ensure the absence of unmapped refs for this object "
"in exported data."
""
"Diagnostic info:"
"1. Serialization of exported object:"
"---------------------------------------------------------------------------------------------------------------------------"
"%4"
"---------------------------------------------------------------------------------------------------------------------------"
"2. Serialization object of unmapped reference"
"---------------------------------------------------------------------------------------------------------------------------"
"%5"
"---------------------------------------------------------------------------------------------------------------------------';ru='Объект метаданных %1 включен в перечень объектов, для которых не требуется сопоставление ссылок при выгрузке / загрузке"
"данных (в переопределяемой процедуре "
"ВыгрузкаЗагрузкаДанныхПереопределяемый.ПриЗаполненииТиповОбщихДанныхНеТребующихСопоставлениеСсылокПриЗагрузке(),"
"но при этом для него не обеспечивается требования отсутствия несопоставляемых ссылок при выгрузке."
""
"Несопоставляемая ссылка обнаружена при выгрузке объекта %2, у которого в качестве значения реквизита %3"
"установлена ссылка на объект %1, которая не сможет быть корректно сопоставлена при загрузке данных."
"Требуется пересмотреть логику использования объекта %1 и обеспечить для него отсутствие несопоставляемых ссылок"
"в выгружаемых данных."
""
"Диагностическая информация:"
"1. Сериализация выгружаемого объекта:"
"---------------------------------------------------------------------------------------------------------------------------"
"%4"
"---------------------------------------------------------------------------------------------------------------------------"
"2. Сериализация объекта несопоставляемой ссылки"
"---------------------------------------------------------------------------------------------------------------------------"
"%5"
"---------------------------------------------------------------------------------------------------------------------------'");
	
	ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
		ErrorTemplate,
		MetadataObject,
		SourceMetadataObject,
		FieldName,
		CommonUse.ValueToXMLString(InitialObject),
		CommonUse.ValueToXMLString(CheckedRefs.GetObject())
	);
	
	Raise ErrorText;
	
EndProcedure

Function MetadataObjectIsDividedByAtLeastOneDelimiter(Val MetadataObject, Cache) Export
	
	For Each CommonAttribute IN Metadata.CommonAttributes Do
		
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			
			AutoUse = (CommonAttribute.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
			
			Content = Cache.Get(CommonAttribute.FullName());
			If Content = Undefined Then
				Content = CommonAttribute.Content;
				Cache.Insert(CommonAttribute.FullName(), Content);
			EndIf;
			
			ContentItem = Content.Find(MetadataObject);
			If ContentItem <> Undefined Then
				
				If ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Use
						OR (AutoUse AND ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Auto) Then
					
					Return True;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction







