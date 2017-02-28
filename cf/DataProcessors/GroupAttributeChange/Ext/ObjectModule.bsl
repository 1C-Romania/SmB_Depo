#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// For an internal use.
Function ExternalDataProcessorInfo() Export
	Var RegistrationParameters;
	
	If SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessorsClientServer = CommonModule("AdditionalReportsAndDataProcessorsClientServer");
		
		RegistrationParameters = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorInfo("2.1.3.1");
		
		RegistrationParameters.Type = ModuleAdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalInformationProcessor();
		RegistrationParameters.Version = "2.2.1";
		RegistrationParameters.SafeMode = False;
		
		NewCommand = RegistrationParameters.Commands.Add();
		NewCommand.Presentation = NStr("en='Group change of attributes';ru='Групповое изменение реквизитов'");
		NewCommand.ID = "OpenGlobally";
		NewCommand.Use = ModuleAdditionalReportsAndDataProcessorsClientServer.TypeCommandsFormOpening();
		NewCommand.ShowAlert = False;
	EndIf;
	
	Return RegistrationParameters;
	
EndFunction

// For an internal use.
Function QueryText(MetadataObject) Export
	
	QueryText = "";
	
	For Each Attribute IN MetadataObject.StandardAttributes Do
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + "," + Chars.LF;
		EndIf;
		QueryText = QueryText + Attribute.Name + " AS " + Attribute.Name;
	EndDo;

	For Each Attribute IN MetadataObject.Attributes Do
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + "," + Chars.LF;
		EndIf;
		QueryText = QueryText + Attribute.Name;
	EndDo;
	
	For Each TabularSection IN MetadataObject.TabularSections Do
		QueryText = QueryText + "," + Chars.LF + TabularSection.Name + ".(";
		AttributesString = "LineNumber";
		For Each Attribute IN TabularSection.Attributes Do
			If Not IsBlankString(AttributesString) Then
				AttributesString = AttributesString + "," + Chars.LF;
			EndIf;
			AttributesString = AttributesString + Attribute.Name;
		EndDo;
		
		QueryText = QueryText + AttributesString +"
		|)";
	EndDo;
	
	QueryText = "SELECT " + QueryText + Chars.LF + "
		|FROM
		|	"+ MetadataObject.FullName();
		
	Return QueryText;
	
EndFunction

// For an internal use.
Function DataCompositionSchema(QueryText) Export
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
EndFunction

// For an internal use.
Procedure RunChangeOfObjects(Parameters, ResultAddress) Export
	
	ProcessedObjects = Parameters.ProcessedObjects.Get().Rows;
	StopChangingAtError = Parameters.StopChangingAtError;
	
	ChangeInTransaction = Parameters.ChangeInTransaction;
	AbortOnError = Parameters.AbortOnError;
	UsedAdditAttributes = Parameters.UsedAdditAttributes;
	UsedAdditInfo = Parameters.UsedAdditInfo;
	
	ObjectsForChange = Parameters.ObjectsForChange.Get().Rows;
	
	ResultOfChange = New Structure("ThereAreErrors, ProcessorState");
	ResultOfChange.ThereAreErrors = False;
	ResultOfChange.ProcessorState = New Map;
	
	If StopChangingAtError = Undefined Then
		StopChangingAtError = AbortOnError;
	EndIf;
	
	If ProcessedObjects = Undefined Then
		ProcessedObjects = New Array;
		For Each AMutableObject IN ObjectsForChange Do
			ProcessedObjects.Add(AMutableObject);
		EndDo;
	EndIf;
	
	If ProcessedObjects.Count() = 0 Then
		PutToTempStorage(ResultOfChange, ResultAddress);
		Return;
	EndIf;
	
	CheckForGroup = CheckForGroup(ProcessedObjects[0].Ref);
	
	If ChangeInTransaction Then
		BeginTransaction(DataLockControlMode.Managed);
	EndIf;
	
	ChangeableAttributes = Parameters.ChangeableAttributes;
	
	For Each ObjectData IN ProcessedObjects Do
		
		Refs = ObjectData.Ref;
		AMutableObject = Refs.GetObject();
		
		Try
			LockDataForEdit(AMutableObject.Ref);
		Except
			Info = ErrorInfo();
			BriefErrorDescription = BriefErrorDescription(Info);
			FillResultOfChanges(ResultOfChange, Refs, "Error_ObjectLockings", BriefErrorDescription);
			If ChangeInTransaction Then
				RollbackTransaction();
				PutToTempStorage(ResultOfChange, ResultAddress);
				Return;
			EndIf;
			If StopChangingAtError Then
				PutToTempStorage(ResultOfChange, ResultAddress);
				Return;
			EndIf;
			Continue;
		EndTry;
		
		ChangedObjectAttributes = New Array;
		AddObjectAttributesAreModified = New Map;
		AdditionalInformationObject = New Map;
		
		AdditionalInformationRecordsArray = New Array;
		
		///////////////////////////////////////////////////////////////////////////////////////
		// Change operation filter for each object.
		//
		
		Cancel = False;
		For Each Operation IN ChangeableAttributes Do
			
			If Operation.OperationKind = 1 Then // change attribute
				
				// For the groups you should not set attributes that they do not have.
				If CheckForGroup AND AMutableObject.IsFolder Then
					If Not ThisIsStandardAttribute(AMutableObject.Metadata().StandardAttributes, Operation.Name) Then
						Continue;
					EndIf;
				EndIf;
				
				Try
					AMutableObject[Operation.Name] = Operation.Value;
				Except
					Cancel = True;
					BriefErrorDescription = BriefErrorDescription(ErrorInfo());
					FillResultOfChanges(ResultOfChange, Refs, "Error_NotClassified", BriefErrorDescription);
					If StopChangingAtError Or ChangeInTransaction Then
						If ChangeInTransaction Then
							RollbackTransaction();
						EndIf;
						PutToTempStorage(ResultOfChange, ResultAddress);
						Return;
					EndIf;
					Break;
				EndTry;
				
				ChangedObjectAttributes.Add(Operation.Name);
				
			ElsIf Operation.OperationKind = 2 Then // change of additional attribute
				
				If Not PropertyNeedToChange(AMutableObject.Ref, Operation.Property, Parameters) Then
					Continue;
				EndIf;
				
				FoundString = AMutableObject.AdditionalAttributes.Find(Operation.Property, "Property");
				
				If FoundString = Undefined Then
					FoundString = AMutableObject.AdditionalAttributes.Add();
					FoundString.Property = Operation.Property;
				EndIf;
				
				FoundString.Value = Operation.Value;
				
				FormAttributeName = PrefixOfNameOfAdditAttribute() + StrReplace(String(Operation.Property.UUID()), "-", "_");
				AddObjectAttributesAreModified.Insert(FormAttributeName, Operation.Value);
				
			ElsIf Operation.OperationKind = 3 Then // change of additional info
				
				If Not PropertyNeedToChange(AMutableObject.Ref, Operation.Property, Parameters) Then
					Continue;
				EndIf;
				
				RecordManager = InformationRegisters["AdditionalInformation"].CreateRecordManager();
				
				RecordManager.Object = AMutableObject.Ref;
				RecordManager.Property = Operation.Property;
				RecordManager.Value = Operation.Value;
				
				AdditionalInformationRecordsArray.Add(RecordManager);
				
				FormAttributeName = PrefixOfNameOfAdditInfo() + StrReplace(String(Operation.Property.UUID()), "-", "_");
				AdditionalInformationObject.Insert(FormAttributeName, Operation.Value);
				
			EndIf;
			
		EndDo; 
		
		If Cancel Then 
			Continue;
		EndIf;
		
		If Parameters.ChangeableTableParts.Count() > 0 Then
			MakeChangesToTabularSections(AMutableObject, ObjectData, Parameters.ChangeableTableParts);
		EndIf;
		
		// Change operation filter for each object.
		///////////////////////////////////////////////////////////////////////////////////////
		
		///////////////////////////////////////////////////////////////////////////////////////
		// Block of filling check processor.
		//
		
		InterruptChange = False;
		FillingCheckSuccessful = True;
		
		Try
			If Not AMutableObject.CheckFilling() Then
				FillResultOfChanges(ResultOfChange, Refs, "Error_FillingCheckingProcessing",
						GetStringOfMessagesAboutErrors());
				If StopChangingAtError Or ChangeInTransaction Then
					InterruptChange = True;
				EndIf;
				FillingCheckSuccessful = False;
			EndIf;
		Except
			Info = ErrorInfo();
			BriefErrorDescription = BriefErrorDescription(Info);
			FillResultOfChanges(ResultOfChange, Refs, "Error_NotClassified", BriefErrorDescription);
			If StopChangingAtError Or ChangeInTransaction Then
				InterruptChange = True;
			EndIf;
			FillingCheckSuccessful = False;
		EndTry;
		
		If InterruptChange Then
			If ChangeInTransaction Then
				RollbackTransaction();
			EndIf;
			PutToTempStorage(ResultOfChange, ResultAddress);
			Return;
		EndIf;
		
		If Not FillingCheckSuccessful Then
			Continue;
		EndIf;
		
		//
		// Block of filling check processor.
		///////////////////////////////////////////////////////////////////////////////////////
		
		///////////////////////////////////////////////////////////////////////////////////////
		// Block of additional info record.
		//
		
		If AdditionalInformationRecordsArray.Count() > 0 Then
			
			If Not ChangeInTransaction Then
				// If a transaction is not used while changing
				// objects, you can use it for changing additional information in the register.
				BeginTransaction(DataLockControlMode.Managed);
			EndIf;
			
			Try
				For Each RecordManager IN AdditionalInformationRecordsArray Do
					RecordManager.Write(True);
				EndDo;
			Except
				Info = ErrorInfo();
				
				BriefErrorDescription = BriefErrorDescription(Info);
				FillResultOfChanges(ResultOfChange, Refs, "Error_AdditionalInformationWriting", BriefErrorDescription);
				
				RollbackTransaction();
				
				If ChangeInTransaction OR StopChangingAtError Then
					PutToTempStorage(ResultOfChange, ResultAddress);
					Return;
				EndIf;
			EndTry;
			
		EndIf;
		
		//
		// Block of additional info record.
		///////////////////////////////////////////////////////////////////////////////////////
		
		Cancel = False;
		
		WriteMode = Undefined;
		ThisIsDocument = Metadata.Documents.Contains(AMutableObject.Metadata());
		If ThisIsDocument Then
			WriteMode = DocumentWriteMode.Write;
			If AMutableObject.Posted Then
				WriteMode = DocumentWriteMode.Posting;
			EndIf;
		EndIf;
			
		Try
			If WriteMode = Undefined Then
				AMutableObject.Write();
			Else
				AMutableObject.Write(WriteMode);
			EndIf;
		Except
			Info = ErrorInfo();
			Cancel = True;
			BriefErrorDescription = BriefErrorDescription(Info);
			FillResultOfChanges(ResultOfChange, Refs, 
							"Error_ObjectRecords",
							BriefErrorDescription + Chars.LF + GetStringOfMessagesAboutErrors());
			If ChangeInTransaction AND TransactionActive() Then // Cancel transaction at any level of recursion.
				RollbackTransaction();
			EndIf;
			If AbortOnError Then
				PutToTempStorage(ResultOfChange, ResultAddress);
				Return;
			EndIf;
		EndTry;
		
		// Commit transaction of additional property records if
		// an object record is not in transaction.
		If Not ChangeInTransaction AND AdditionalInformationRecordsArray.Count() > 0 Then
			CommitTransaction();
		EndIf;
		
		If Not Cancel Then
			FillChangeResultAdditionalProperties(ResultOfChange, Refs,
						AMutableObject, ChangedObjectAttributes,
						AddObjectAttributesAreModified, AdditionalInformationObject);
		EndIf;
		
		UnlockDataForEdit(AMutableObject.Ref);
		
	EndDo;
	
	If ChangeInTransaction AND TransactionActive() Then
		CommitTransaction();
	EndIf;
	
	PutToTempStorage(ResultOfChange, ResultAddress);
	Return;

EndProcedure

Function PropertyNeedToChange(Refs, Property, Parameters)
	
	ObjectsForChange = Parameters.ObjectsForChange;
	If SubsystemExists("StandardSubsystems.Properties") Then
		PropertiesManagementModule = CommonModule("PropertiesManagement");
		If PropertiesManagementModule = Undefined Then
			Return False;
		EndIf;
	EndIf;
	
	ObjectKindByRef = ObjectKindByRef(Refs);
	If (ObjectKindByRef = "Catalog" OR ObjectKindByRef = "ChartOfCharacteristicTypes")
		AND ObjectIsFolder(Refs) Then
		Return False;
	EndIf;
	
	If Not PropertiesManagementModule.CheckObjectProperty(Refs, Property) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function GetStringOfMessagesAboutErrors()
	
	ErrorPresentation = "";
	MessagesArray = GetUserMessages(True);
	
	For Each UserMessage IN MessagesArray Do
		ErrorPresentation = ErrorPresentation + UserMessage.Text + Chars.LF;
	EndDo;
	
	Return ErrorPresentation;
	
EndFunction

Procedure FillResultOfChanges(Result, Refs, ErrorCode, ErrorInfo)
	
	ChangeState = New Structure;
	ChangeState.Insert("ErrorCode", ErrorCode);
	ChangeState.Insert("ErrorInfo", ErrorInfo);
	
	Result.ProcessorState.Insert(Refs, ChangeState);
	Result.ThereAreErrors = True;
	
EndProcedure

Procedure FillChangeResultAdditionalProperties(Result, Refs, 
		AMutableObject, ChangedObjectAttributes = Undefined,
		AddObjectAttributesAreModified = Undefined, AdditionalInformationObject = Undefined)
	
	ChangeState = New Structure;
	ChangeState.Insert("ErrorCode", "");
	ChangeState.Insert("ErrorInfo", "");
	ChangeState.Insert("ValuesChangedDetails", New Map);
	If ChangedObjectAttributes <> Undefined Then
		For Each AttributeName IN ChangedObjectAttributes Do
			ChangeState.ValuesChangedDetails.Insert(AttributeName, AMutableObject[AttributeName]);
		EndDo;
	EndIf;
	ChangeState.Insert("ChangedAdditionalAttributesValues", AddObjectAttributesAreModified);
	ChangeState.Insert("ChangedAdditionalInformationValues", AdditionalInformationObject);
	
	Result.ProcessorState.Insert(Refs, ChangeState);
	
EndProcedure

Function PrefixOfNameOfAdditAttribute()
	Return "AdditionalAttribute_";
EndFunction

Function PrefixOfNameOfAdditInfo()
	Return "AdditInfo_";
EndFunction

Function CheckForGroup(Refs)
	
	ObjectKind = ObjectKindByRef(Refs);
	ObjectMetadata = Refs.Metadata();
	
	If ObjectKind = "Catalog"
	   AND ObjectMetadata.Hierarchical
	   AND ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

Procedure MakeChangesToTabularSections(AMutableObject, ObjectData, TablularSectionsChanges)
	For Each TabularSectionChanges IN TablularSectionsChanges Do
		TableName = TabularSectionChanges.Key;
		ChangeableAttributes = TabularSectionChanges.Value;
		For Each TableRow IN AMutableObject[TableName] Do
			If StringMatchesFilter(TableRow, ObjectData, TableName) Then
				For Each VariableAttribute IN ChangeableAttributes Do
					TableRow[VariableAttribute.Name] = VariableAttribute.Value;
				EndDo;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

Function StringMatchesFilter(TableRow, ObjectData, TableName)
	
	Return ObjectData.Rows.FindRows(New Structure(TableName + "LineNumber", TableRow.LineNumber)).Count() = 1;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedure and function of basic functionality to ensure independence.

// Returns the flag showing that the attribute is included into the subset of standard attributes.
// 
// Parameters:
//  StandardAttributes - StandardAttributesDescription - type and value describes the
//                                                         collection of settings for various standard attributes;
//  AttributeName - String - attribute to be checked for inclusion into standard attribute set.;
// 
//  Returns:
//   Boolean.
//
Function ThisIsStandardAttribute(StandardAttributes, AttributeName) Export
	
	For Each Attribute IN StandardAttributes Do
		If Attribute.Name = AttributeName Then
			Return True;
		EndIf;
	EndDo;
	Return False;
	
EndFunction

// Function ObjectKindByRef returns the type name
// for the metadata objects by the link to the object.
//
// Points of business processes are not processed.
//
// Parameters:
//  Refs       - refer to object, - catalog item, document, ...
//
// Returns:
//  String       - metadata object kind name, for example, "Catalog" "Document" ...
// 
Function ObjectKindByRef(Refs) Export
	
	Return ObjectKindByKind(TypeOf(Refs));
	
EndFunction 

// Function returns the metadata object kind name based on the object type.
//
// Points of business processes are not processed.
//
// Parameters:
//  Type       - Type of applied object defined in configuration.
//
// Returns:
//  String       - metadata object kind name, for example, "Catalog" "Document" ...
// 
Function ObjectKindByKind(Type) Export
	
	If Catalogs.AllRefsType().ContainsType(Type) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(Type) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(Type) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(Type) Then
		Return "Enum";
	
	Else
		Raise PlaceParametersIntoString(
			NStr("en='InvalidValueTypeParameter%1';ru='Неверный тип значения параметра (%1)'"), String(Type));
	
	EndIf;
	
EndFunction 

// Checks whether the object is a group of items.
//
// Parameters:
//  Object       - Object, Reference, FormDataStructure by Object type.
//
// Returns:
//  Boolean.
//
Function ObjectIsFolder(Object) Export
	
	If ReferenceTypeValue(Object) Then
		Refs = Object;
	Else
		Refs = Object.Ref;
	EndIf;
	
	ObjectMetadata = Refs.Metadata();
	
	If Metadata.Catalogs.Contains(ObjectMetadata) Then
		
		If Not ObjectMetadata.Hierarchical
		 OR ObjectMetadata.HierarchyType
		     <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			
			Return False;
		EndIf;
		
	ElsIf Not Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata) Then
		Return False;
		
	ElsIf Not ObjectMetadata.Hierarchical Then
		Return False;
	EndIf;
	
	If Refs <> Object Then
		Return Object.IsFolder;
	EndIf;
	
	Return ObjectAttributeValue(Refs, "IsFolder");
	
EndFunction

// Verify that the value has a reference data type.
//
// Parameters:
//  Value       - refer to object, - catalog item, document, ...
//
// Returns:
//  Boolean       - True if value type is reference.
//
Function ReferenceTypeValue(Value) Export
	
	If Value = Undefined Then
		Return False;
	EndIf;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Enums.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfAccounts.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.RoutePointsAllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Tasks.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ExchangePlans.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// It returns a structure containing attribute values read
// from the infobase by the object link.
// 
//  If there is no access to one of the attributes, access right exception will occur.
//  If it is required to read the attribute
//  regardless of the current user rights, then you should use preliminary transition to the privileged mode.
// 
// Parameters:
//  Refs    - Object ref - catalog item, document, ...
//
//  Attributes - String - attribute names listed comma separated in
//              the format of structure property requirements.
//              For example, "Code, Name, Parent".
//            - Structure, FixedStructure - field alias name
//              is transferred as a key for the returned structure with
//              the result and actual field name in the table is transferred (optionally) as the value.
//              If the value is not specified, then the field name is taken from the key.
//            - Array, FixedArray - attribute names in the
//              format of requirements to the structure properties.
//
// Returns:
//  Structure - includes names (keys) and values of the requested attribute.
//              If a row of the claimed attributes is empty, then an empty structure returns.
//
Function ObjectAttributesValues(Refs, Val Attributes) Export
	
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		Attributes = DecomposeStringIntoSubstringsArray(Attributes, ",", True);
	EndIf;
	
	AttributesStructure = New Structure;
	If TypeOf(Attributes) = Type("Structure") Or TypeOf(Attributes) = Type("FixedStructure") Then
		AttributesStructure = Attributes;
	ElsIf TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		For Each Attribute IN Attributes Do
			AttributesStructure.Insert(StrReplace(Attribute, ".", ""), Attribute);
		EndDo;
	Else
		Raise PlaceParametersIntoString(
			NStr("en='Invalid type of Attributes second parameter: %1';ru='Неверный тип второго параметра Реквизиты: %1'"),
			String(TypeOf(Attributes)));
	EndIf;
	
	FieldTexts = "";
	For Each KeyAndValue IN AttributesStructure Do
		FieldName   = ?(ValueIsFilled(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Key));
		
		Alias = TrimAll(KeyAndValue.Key);
		
		FieldTexts  = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "
		|	" + FieldName + " AS " + Alias;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Refs);
	Query.Text =
	"SELECT
	|" + FieldTexts + "
	|FROM
	|	" + Refs.Metadata().FullName() + " AS
	|SpecifiedTableAlias
	|WHERE SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = New Structure;
	For Each KeyAndValue IN AttributesStructure Do
		Result.Insert(KeyAndValue.Key);
	EndDo;
	FillPropertyValues(Result, Selection);
	
	Return Result;
	
EndFunction

// Returns attribute value read from the infobase using the object link.
// 
//  If there is no access to the attribute, access rights exception occurs.
//  If it is required to read the attribute
//  regardless of the current user rights, then you should use preliminary transition to the privileged mode.
// 
// Parameters:
//  Refs       - refer to object, - catalog item, document, ...
//  AttributeName - String, for example, "Code".
// 
// Returns:
//  Arbitrary    - depends on the value type of read attribute.
// 
Function ObjectAttributeValue(Refs, AttributeName) Export
	
	Result = ObjectAttributesValues(Refs, AttributeName);
	Return Result[StrReplace(AttributeName, ".", "")];
	
EndFunction 

// It splits a line into several lines according to a delimiter. Delimiter may have any length.
//
// Parameters:
//  String                 - String - Text with delimiters;
//  Delimiter            - String - Delimiter of text lines, minimum 1 symbol;
//  SkipBlankStrings - Boolean - Flag of necessity to show empty lines in the result.
//    If the parameter is not specified, the function works in the mode of compatibility with its previous version:
//     - for delimiter-space empty lines are not included in the result, for other
//       delimiters empty lines are included in the result.
//     E if Line parameter does not contain significant characters or does not contain any symbol (empty line),
//       then for delimiter-space the function result is an array containing one value ""
//       (empty line) and for other delimiters the function result is the empty array.
//
//
// Returns:
//  Array - array of rows.
//
// Examples:
//  DecomposeStringIntoSubstringsArray(",one,,two,", ",") - it will return the array of 5 elements three of which  - empty
//  lines;
//  DecomposeStringIntoSubstringsArray(",one,,two,", ",", True) - it will return an array of two items;
//  DecomposeStringIntoSubstringArray("one two ", " ") - it will return an array of two items;
//  DecomposeStringIntoSubstringArray("") - It returns an empty array;
//  DecomposeStringIntoSubstringsArray("",,False) - It returns an array with one element "" (empty line);
//  DecomposeStringIntoSubstringsArray("", " ") - It returns an array with one element "" (empty line);
//
Function DecomposeStringIntoSubstringsArray(Val String, Val Delimiter = ",", Val SkipBlankStrings = Undefined) Export
	
	Result = New Array;
	
	// To ensure backward compatibility.
	If SkipBlankStrings = Undefined Then
		SkipBlankStrings = ?(Delimiter = " ", True, False);
		If IsBlankString(String) Then 
			If Delimiter = " " Then
				Result.Add("");
			EndIf;
			Return Result;
		EndIf;
	EndIf;
	//
	
	Position = Find(String, Delimiter);
	While Position > 0 Do
		Substring = Left(String, Position - 1);
		If Not SkipBlankStrings Or Not IsBlankString(Substring) Then
			Result.Add(Substring);
		EndIf;
		String = Mid(String, Position + StrLen(Delimiter));
		Position = Find(String, Delimiter);
	EndDo;
	
	If Not SkipBlankStrings Or Not IsBlankString(String) Then
		Result.Add(String);
	EndIf;
	
	Return Result;
	
EndFunction 

// It substitutes the parameters into the string. 
// Parameters in the line are specified as %<parameter number>. Parameter numbering starts with one.
//
// Parameters:
//  LookupString  - String - String template with parameters (inclusions of "%ParameterName" type);
//  Parameter<n>        - String - substituted parameter.
//
// Returns:
//  String   - text string with substituted parameters.
//
// Example:
//  PlaceParametersIntoString(NStr("en='%1 went to %2';ru='%1 пошел в %2'"), "John", "Zoo") = "John went to the Zoo".
//
Function PlaceParametersIntoString(Val LookupString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	LookupString = StrReplace(LookupString, "%1", Parameter1);
	LookupString = StrReplace(LookupString, "%2", Parameter2);
	LookupString = StrReplace(LookupString, "%3", Parameter3);
	Return LookupString;
EndFunction

// Returns True if the subsystem exists.
//
// Parameters:
//  SubsystemFullName - String. Full metadata object name, subsystem without words "Subsystem.".
//                        For example, StandardSubsystems.BasicFunctionality.
//
// Example of optional subsystem call:
//
//  If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement")
//  	Then AccessControlModule = CommonUse.CommonModule("AccessManagement");
//  	AccessManagementModule.<Method name>();
//  EndIf;
//
// Returns:
//  Boolean.
//
Function SubsystemExists(SubsystemFullName) Export
	
	NamesSubsystems = NamesSubsystems();
	Return NamesSubsystems.Get(SubsystemFullName) <> Undefined;
	
EndFunction

// Returns matching of subsystem names and True value;
Function NamesSubsystems() Export
	
	Return New FixedMap(NamesSubordinateSubsystems(Metadata));
	
EndFunction

Function NamesSubordinateSubsystems(ParentSubsystem)
	
	names = New Map;
	
	For Each CurrentSubsystem IN ParentSubsystem.Subsystems Do
		
		names.Insert(CurrentSubsystem.Name, True);
		NamesOfSubordinate = NamesSubordinateSubsystems(CurrentSubsystem);
		
		For Each NameSubordinate IN NamesOfSubordinate Do
			names.Insert(CurrentSubsystem.Name + "." + NameSubordinate.Key, True);
		EndDo;
	EndDo;
	
	Return names;
	
EndFunction

// It returns a reference to the common module by name.
//
// Parameters:
//  Name          - String - common module name, for example:
//                 "CommonUse",
//                 "CommonUseClient".
//
// Returns:
//  CommonModule.
//
Function CommonModule(Name) Export
	
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		Module = Eval(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise PlaceParametersIntoString(
			NStr("en='Common module ""%1"" is not found.';ru='Общий модуль ""%1"" не найден.'"), Name);
	EndIf;
	
	Return Module;
	
EndFunction

#EndRegion

#EndIf