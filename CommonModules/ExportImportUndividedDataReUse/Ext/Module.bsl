////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Returns dependencies of undivided metadata objects.
// If the metadata object contains a field the type of which value is
// a reference to another metadata object, it is considered that it depends on it.
//
// Returns:
//  FixedMap:
//    * Key - String, full name of the dependent metadata object, * Value - Array(Row) - full names of metadata objects on which this metadata object depends.
//
Function DependenciesUndividedMetadataObjects() Export
	
	Cache = New Map();
	
	CommonClassifierTypes = DataExportImportServiceEvents.GetCommonDataTypesSupportMatchingRefsOnImport();
	
	For Each CommonClassifierType IN CommonClassifierTypes Do
		
		Manager = ServiceTechnologyIntegrationWithSSL.ObjectManagerByFullName(CommonClassifierType.FullName());
		
		NaturalKeyFields = Manager.NaturalKeyFields();
		For Each NaturalKeyField IN NaturalKeyFields Do
			
			FieldTypes = Undefined;
			
			For Iterator = 0 To CommonClassifierType.StandardAttributes.Count() - 1 Do
				
				// Search  in standard attributes
				StandardAttribute = CommonClassifierType.StandardAttributes[Iterator];
				If StandardAttribute.Name = NaturalKeyField Then
					FieldTypes = StandardAttribute.Type;
				EndIf;
				
			EndDo;
			
			// Search in attributes
			Attribute = CommonClassifierType.Attributes.Find(NaturalKeyField);
			If Attribute <> Undefined Then
				FieldTypes = Attribute.Type;
			EndIf;
			
			// Search in common attributes
			CommonAttribute = Metadata.CommonAttributes.Find(NaturalKeyField);
			If CommonAttribute <> Undefined Then
				For Each CommonAttribute IN Metadata.CommonAttributes Do
					If CommonAttribute.Content.Find(CommonClassifierType) <> Undefined Then
						FieldTypes = CommonAttribute.Type;
					EndIf;
				EndDo;
			EndIf;
			
			If FieldTypes = Undefined Then
				
				Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
					NStr("en = 'the %1 field can not be used as the natural key field of the %2 object: object field has not been detected!'", Metadata.DefaultLanguage.LanguageCode),
					NaturalKeyField,
					CommonClassifierType.FullName()
				);
				
			EndIf;
			
			For Each FieldType IN FieldTypes.Types() Do
				
				If Not CommonUseSTL.IsPrimitiveType(FieldType) AND Not CommonUseSTL.IsEnum(DataExportImportService.MetadataObjectByTypeRefs(FieldType)) Then
					
					If FieldType = Type("ValueStorage") Then
						
						Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
							NStr("en = 'The %1 field is can not be used as a field
                                  |of natural object key %2: using of values ValueStorage type as fields of natural key is not supported!'", Metadata.DefaultLanguage.LanguageCode),
							NaturalKeyField,
							CommonClassifierType.FullName()
						);
						
					EndIf;
					
					Refs = New(FieldType);
					
					If CommonClassifierTypes.Find(Refs.Metadata()) <> Undefined Then
						
						If Cache.Get(CommonClassifierType.FullName()) <> Undefined Then
							Cache.Get(CommonClassifierType.FullName()).Add(Refs.Metadata().FullName());
						Else
							NewArray = New Array();
							NewArray.Add(Refs.Metadata().FullName());
							Cache.Insert(CommonClassifierType.FullName(), NewArray);
						EndIf;
						
					Else
						
						Raise StringFunctionsClientServer.PlaceParametersIntoString(
							NStr("en = 'The %1 field is can not be used as a
                                  |field of natural object key %2: as field type can be
                                  |used object %3 which is
                                  |not included in the common data set through predefined procedure DataExportImportPredefined.WhenFillingCommonDataTypesSupportingMatchingRefsOnImport()'", Metadata.DefaultLanguage.LanguageCode),
							NaturalKeyField,
							CommonClassifierType.FullName(),
							Refs.Metadata().FullName()
						);
						
					EndIf;
					
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	Return New FixedMap(Cache);
	
EndFunction

// Returns the control rules of references to undivided data in data divided during export.
//
// Returns:
//  FixedMap:
//    * Key - String - full name of the metadata object for which
//       presence control of the references to undivided data in separated during exporting data must be executed.
//    1C:Document Management web service URL initial value - Array(Row) - the array of the object fields names
//       in which the presence control of the references to undivided data in separated during exporting data must be executed.
//
Function ControlReferencesToUndividedDataInSeparatedOnExport() Export
	
	Cache = New Map();
	
	CommonDataTypes = DataExportImportServiceEvents.GetCommonDataTypesSupportMatchingRefsOnImport();
	ObjectsExcludedFromExportImport = DataExportImportServiceEvents.GetTypesExcludedFromExportImport();
	ObjectsDoNotRequireMatchingRefs = DataExportImportServiceEvents.GetCommonDataTypesDoNotRequireMatchingRefsOnImport();
	
	LocalCacheSeparatorsContents = New Map();
	
	For Each MetadataObject IN DataExportImportService.AllConstants() Do
		FillReferencesControlCacheUndividedDataOnExportForConstants(
			Cache, MetadataObject, CommonDataTypes, ObjectsExcludedFromExportImport, ObjectsDoNotRequireMatchingRefs,
				LocalCacheSeparatorsContents
		);
	EndDo;
	
	For Each MetadataObject IN DataExportImportService.AllReferenceData() Do
		FillReferencesControlCacheUndividedDataOnExportForObjects(
			Cache, MetadataObject, CommonDataTypes, ObjectsExcludedFromExportImport, ObjectsDoNotRequireMatchingRefs,
				LocalCacheSeparatorsContents
		);
	EndDo;
	
	For Each MetadataObject IN DataExportImportService.AllRecordSets() Do
		FillReferencesControlCacheUndividedDataOnExportForRecordSets(
			Cache, MetadataObject, CommonDataTypes, ObjectsExcludedFromExportImport, ObjectsDoNotRequireMatchingRefs,
				LocalCacheSeparatorsContents
		);
	EndDo;
	
	Return New FixedMap(Cache);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FillReferencesControlCacheUndividedDataOnExportForConstants(Cache, Val MetadataObject, Val CommonDataTypes, Val ObjectsExcludedFromExportImport, Val ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent)
	
	If ObjectsExcludedFromExportImport.Find(MetadataObject) = Undefined AND UndividedDataExportImport.MetadataObjectIsDividedByAtLeastOneDelimiter(MetadataObject, LocalCacheSeparatorsContent) Then
		
		FillReferencesControlCacheUndividedDataOnExportOnDividedObjectField(
			Cache, MetadataObject, MetadataObject, CommonDataTypes, ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent
		);
		
	EndIf;
	
EndProcedure

Procedure FillReferencesControlCacheUndividedDataOnExportForObjects(Cache, Val MetadataObject, Val CommonDataTypes, Val ObjectsExcludedFromExportImport, Val ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent)
	
	If ObjectsExcludedFromExportImport.Find(MetadataObject) = Undefined AND UndividedDataExportImport.MetadataObjectIsDividedByAtLeastOneDelimiter(MetadataObject, LocalCacheSeparatorsContent) Then
		
		For Each Attribute IN MetadataObject.Attributes Do
			
			FillReferencesControlCacheUndividedDataOnExportOnDividedObjectField(
				Cache, MetadataObject, Attribute, CommonDataTypes, ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent
			);
			
		EndDo;
		
		For Each TabularSection IN MetadataObject.TabularSections Do
			
			For Each Attribute IN TabularSection.Attributes Do
				
				FillReferencesControlCacheUndividedDataOnExportOnDividedObjectField(
					Cache, MetadataObject, Attribute, CommonDataTypes, ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent
				);
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillReferencesControlCacheUndividedDataOnExportForRecordSets(Cache, Val MetadataObject, Val CommonDataTypes, Val ObjectsExcludedFromExportImport, Val ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent)
	
	If ObjectsExcludedFromExportImport.Find(MetadataObject) = Undefined AND UndividedDataExportImport.MetadataObjectIsDividedByAtLeastOneDelimiter(MetadataObject, LocalCacheSeparatorsContent) Then
		
		For Each Dimension IN MetadataObject.Dimensions Do
			
			FillReferencesControlCacheUndividedDataOnExportOnDividedObjectField(
				Cache, MetadataObject, Dimension, CommonDataTypes, ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent
			);
			
		EndDo;
		
		For Each Resource IN MetadataObject.Resources Do
			
			FillReferencesControlCacheUndividedDataOnExportOnDividedObjectField(
				Cache, MetadataObject, Resource, CommonDataTypes, ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent
			);
			
		EndDo;
		
		For Each Attribute IN MetadataObject.Attributes Do
			
			FillReferencesControlCacheUndividedDataOnExportOnDividedObjectField(
				Cache, MetadataObject, Attribute, CommonDataTypes, ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContent
			);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillReferencesControlCacheUndividedDataOnExportOnDividedObjectField(Cache, Val MetadataObject, Val Field, Val CommonDataTypes, Val ObjectsDoNotRequireMatchingRefs, LocalCacheSeparatorsContents)
	
	FieldTypes = Field.Type;
	
	If CommonUseSTL.IsRefsTypesSet(FieldTypes) Then
		
		// For the attribute the type AnyReference is set or
		// composite type CatalogRef.*, DocumentRef.* etc. - at this stage check will not be executed, as the
		// developer could imply any reference of divided reference metadata object.
		//
		// Information about the object and the attribute will be saved
		// in the cache and further used for executing the check at the time of exporting that data which really will be exported.
		//
		
		If Cache.Get(MetadataObject.FullName()) = Undefined Then
			Cache.Insert(MetadataObject.FullName(), New Array());
		EndIf;
		
		Cache.Get(MetadataObject.FullName()).Add(Field.FullName());
		
	Else
		
		For Each FieldType IN FieldTypes.Types() Do
			
			If Not CommonUseSTL.IsPrimitiveType(FieldType) AND Not (FieldType = Type("ValueStorage")) Then
				
				MetadataRefs = DataExportImportService.MetadataObjectByTypeRefs(FieldType);
				
				If CommonDataTypes.Find(MetadataRefs) = Undefined
						AND Not CommonUseSTL.IsEnum(MetadataRefs)
						AND Not UndividedDataExportImport.MetadataObjectIsDividedByAtLeastOneDelimiter(MetadataRefs, LocalCacheSeparatorsContents) Then
					
					If ObjectsDoNotRequireMatchingRefs.Find(MetadataRefs) = Undefined Then
						
						RaiseExceptionOnPresenceDividedDataRefsToUndividedWithoutSupportingMatchingRefs(
							MetadataObject,
							Field.FullName(),
							MetadataRefs,
							False
						);
						
					Else
						
						If Cache.Get(MetadataObject.FullName()) = Undefined Then
							Cache.Insert(MetadataObject.FullName(), New Array());
						EndIf;
						
						Cache.Get(MetadataObject.FullName()).Add(Field.FullName());
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure RaiseExceptionOnPresenceDividedDataRefsToUndividedWithoutSupportingMatchingRefs(Val MetadataObject, Val FieldName, Val MetadataRefs, Val OnExport)
	
	If CommonUseSTL.ThisIsConstant(MetadataObject) Then
		
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'As the value of divided constant %1 the
                  |references to undivided %2 object are used'", Metadata.DefaultLanguage.LanguageCode),
			MetadataObject.FullName(),
			MetadataRefs.FullName()
		);
		
	ElsIf CommonUseSTL.ThisIsReferenceData(MetadataObject) Then
		
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'As the value of attribute %1 the divided  object %2
                  |the references to undivided object %3 are used'", Metadata.DefaultLanguage.LanguageCode),
			FieldName,
			MetadataObject.FullName(),
			MetadataRefs.FullName()
		);
		
	ElsIf CommonUseSTL.ThisIsRecordSet(MetadataObject) Then
		
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'As the value of measurement, resource or attribute %1 divided record set %2 the
                  |references to undivided object %3 are used'", Metadata.DefaultLanguage.LanguageCode),
			FieldName,
			MetadataObject.FullName(),
			MetadataRefs.FullName()
		);
		
	Else
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Unexpected metadata object: %1!'", Metadata.DefaultLanguage.LanguageCode),
			MetadataObject.FullName()
		);
		
	EndIf;
	
	If OnExport Then
		
		ErrorText = ErrorText +
			NStr("en = ' (the composite data type is set for the object as the value type, and which contain references both to undivided and separated data, but there was detected an attempt to export the references to undivided object).'", Metadata.DefaultLanguage.LanguageCode);
		
	Else
		
		ErrorText = ErrorText + ".";
		
	EndIf;
	
	ErrorSupplement = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en = 'In this case undivided %1 object is not included in the
              |content of the common data types for which the execution of matching refs during exporting and importing is possible.
              |This situation is unacceptable, as on importing of exported data in
              |another IB ""broken"" references to %1 object will be imported.
              |
              |For corrective action it is required to implement for
              |%1 object mechanism of defining fields that uniquely identify the natural key
              |of the object and include %1 object in the content
              |of common data types for which the execution of
              |matching refs during exporting and importing is possible, specified the metadata %1 object in the procedure DataExportImportPredefined.WhenFillingCommonDataTypesSupportingMatchingRefsOnImport().'", Metadata.DefaultLanguage.LanguageCode),
		MetadataRefs.FullName()
	);
	
	If Not OnExport Then
		
		ErrorSupplement = ErrorSupplement + StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = '
                  |If the correct matching refs of undivided IB data from which
                  |the data is exported and the IB in which the data is imported
                  |is guaranteed by using other mechanisms
                  |you must specify metadata %1 object in the procedure DataExportImportPredefined.WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport().'", Metadata.DefaultLanguage.LanguageCode),
			MetadataRefs.FullName()
		);
		
	EndIf;
	
	Raise ErrorText + Chars.LF + Chars.CR + ErrorSupplement;
	
EndProcedure

#EndRegion