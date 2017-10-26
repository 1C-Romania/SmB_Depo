////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - for work with data in base;
// - for work with the applied types and collections of values;
// - mathematical procedures and functions;
// - for work with external connection;
// - for work with froms;
// - for work with types, metadata objects and their row presentations.;
// - functions of metadata objects types definition;
// - saving, reading and deleting settings from storages;
// - for work with tabular documents;
// - for work with the events log monitor;
// - for work in the data separation mode;
// - application interfaces versioning;
// - helper procedures and functions.
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions for work with data in base.

// It returns a structure containing attribute values read
// from the infobase by the object link.
// 
//  If there is no access to one of the attributes, access right exception will occur.
//  If it is required to read the attribute
//  regardless of the current user rights, then you should use preliminary transition to the privileged mode.
// 
// Function is not designed for receiving attributes values of empty refs.
//
// Parameters:
//  Ref    - AnyRef - object attributes values of which it is required to receive.
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
//              If a null reference is transferred as an object, then all attributes return with the Undefined value.
//
Function ObjectAttributesValues(Ref, Val Attributes) Export
	
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		Attributes = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Attributes, ",", True);
	EndIf;
	
	AttributesStructure = New Structure;
	If TypeOf(Attributes) = Type("Structure") Or TypeOf(Attributes) = Type("FixedStructure") Then
		AttributesStructure = Attributes;
	ElsIf TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		For Each Attribute In Attributes Do
			AttributesStructure.Insert(StrReplace(Attribute, ".", ""), Attribute);
		EndDo;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Invalid type of Attributes second parameter: %1';ru='Неверный тип второго параметра Реквизиты: %1'"),
			String(TypeOf(Attributes)));
	EndIf;
	
	FieldTexts = "";
	For Each KeyAndValue In AttributesStructure Do
		FieldName   = ?(ValueIsFilled(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Key));
		
		Alias = TrimAll(KeyAndValue.Key);
		
		FieldTexts  = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "
		|	" + FieldName + " AS " + Alias;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|" + FieldTexts + "
	|FROM
	|	" + Ref.Metadata().FullName() + " AS
	|SpecifiedTableAlias
	|WHERE SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = New Structure;
	For Each KeyAndValue In AttributesStructure Do
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
// Function is not designed for receiving attributes values of empty refs.
// 
// Parameters:
//  Ref       - ref to object, - catalog item, document, ...
//  AttributeName - String, for example, "Code".
// 
// Returns:
//  Arbitrary    - depends on the value type of read attribute.
// 
Function ObjectAttributeValue(Ref, AttributeName) Export
	
	Result = ObjectAttributesValues(Ref, AttributeName);
	Return Result[StrReplace(AttributeName, ".", "")];
	
EndFunction 

// Returns a structure that contains attribute values read from the infobase by
// object reference.
// 
// If access to any of the attributes is denied, an exception is raised.
// To be able to read attribute values irrespective of current user rights, 
// turn privileged mode on.
// 
// Is not intended for retrieving empty reference attribute values.
//
// Parameters:
//  Ref        - AnyRef - reference to the object whose attribute values are retrieved.
//  Attributes - String - attribute names separated with commas, formatted according to
//               structure requirements 
//               Example: "Code, Description, Parent".
//             - Structure, FixedStructure -  keys are field aliases used for resulting
//               structure keys, values (optional) are field names. If a value is empty, it
//               is considered equal to the key.
//             - Array, FixedArray - attribute names formatted according to structure
//               property requirements.
//
// Returns:
//  Structure - contains names (keys) and values of the requested attributes.
//              If the string of the requested attributes is empty, an empty structure is returned.
//              If an empty reference is passed as the object reference, all return attribute
//              will be Undefined.
//
Function ObjectAttributeValues(Ref, Val Attributes) Export
	
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		Attributes = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Attributes, ",", True);
	EndIf;
	
	AttributeStructure = New Structure;
	If TypeOf(Attributes) = Type("Structure") Or TypeOf(Attributes) = Type("FixedStructure") Then
		AttributeStructure = Attributes;
	ElsIf TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		For Each Attribute In Attributes Do
			AttributeStructure.Insert(StrReplace(Attribute, ".", ""), Attribute);
		EndDo;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid Attributes parameter type: %1'; ru = 'Неверный тип параметра Атрибута %1'"),
			String(TypeOf(Attributes)));
	EndIf;
	
	FieldTexts = "";
	For Each KeyAndValue In AttributeStructure Do
		FieldName   = ?(ValueIsFilled(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Key));
		
		Alias = TrimAll(KeyAndValue.Key);
		
		FieldTexts  = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "" + FieldName + " AS " + Alias;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|" + FieldTexts + " FROM " + Ref.Metadata().FullName() + " AS SpecifiedTableAlias
	| WHERE
	| SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = New Structure;
	For Each KeyAndValue In AttributeStructure Do
		Result.Insert(KeyAndValue.Key);
	EndDo;
	FillPropertyValues(Result, Selection);
	
	Return Result;
	
EndFunction

// Returns the attributes values read from the infobase for multiple objects.
// 
//  If there is no access to the attribute, access rights exception occurs.
//  If it is required to read the attribute
//  regardless of the current user rights, then you should use preliminary transition to the privileged mode.
// 
// Function is not designed for receiving attributes values of empty refs.
// 
// Parameters:
//  RefArray - array of references to objects of the same type.
// 			IMPORTANT! values of the array should be references to objects of the same type.
//  AttributeName - String, for example, "Code".
// 
// Returns:
//  Map - Key - ref to object, Value - value of the read attribute.
// 
Function ObjectsAttributeValue(RefArray, AttributeName) Export
	
	AttributeValues = ObjectAttributeValues(RefArray, AttributeName);
	For Each Item In AttributeValues Do
		AttributeValues[Item.Key] = Item.Value[AttributeName];
	EndDo;
		
	Return AttributeValues;
	
EndFunction

// Checks if the documents are posted.
//
// Parameters:
//  Documents - Array - documents posting of which is required to be checked.
//
// Returns:
//  Array - unposted documents from the Documents array.
//
Function CheckThatDocumentsArePosted(Val Documents) Export
	
	Result = New Array;
	
	QueryPattern = 	
		"SELECT
		|	SpecifiedTableAlias.Ref AS Ref
		|FROM
		|	&DocumentName AS SpecifiedTableAlias
		|WHERE
		|	SpecifiedTableAlias.Ref In(&DocumentArray)
		|	AND Not SpecifiedTableAlias.Posted";
	
	UnionAllText =
		"
		|
		|UNION ALL
		|
		|";
		
	DocumentNames = New Array;
	For Each Document In documents Do
		DocumentMetadata = Document.Metadata();
		If DocumentNames.Find(DocumentMetadata.FullName()) = Undefined
			AND Metadata.Documents.Contains(DocumentMetadata)
			AND DocumentMetadata.Posting = Metadata.ObjectProperties.Posting.Allow Then
				DocumentNames.Add(DocumentMetadata.FullName());
		EndIf;
	EndDo;
	
	QueryText = "";
	For Each DocumentName In documentNames Do
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + UnionAllText;
		EndIf;
		SubqueryText = StrReplace(QueryPattern, "&DocumentName", DocumentName);
		QueryText = QueryText + SubqueryText;
	EndDo;
		
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("DocumentArray", Documents);
	
	If Not IsBlankString(QueryText) Then
		Result = Query.Execute().Unload().UnloadColumn("Ref");
	EndIf;
	
	Return Result;
	
EndFunction

// Attempts to post documents.
//
// Parameters:
// Documents                - Array - documents required to be posted.
//
// Returns:
// Array - array of structures with fields:
// 		 Ref         - document that failed to be posted;
// 		 ErrorDescription - text of error on posting description.
//
Function PostDocuments(Documents) Export
	
	UnpostedDocuments = New Array;
	
	For Each DocumentRef In documents Do
		
		CompletedSuccessfully = False;
		DocumentObject = DocumentRef.GetObject();
		If DocumentObject.CheckFilling() Then
			Try
				DocumentObject.Write(DocumentWriteMode.Posting);
				CompletedSuccessfully = True;
			Except
				ErrorPresentation = BriefErrorDescription(ErrorInfo());
			EndTry;
		Else
			ErrorPresentation = NStr("en='Document fields are not populated.';ru='Поля документа не заполнены.'");
		EndIf;
		
		If Not CompletedSuccessfully Then
			UnpostedDocuments.Add(New Structure("Ref,ErrorDescription", DocumentRef, ErrorPresentation));
		EndIf;
		
	EndDo;
	
	Return UnpostedDocuments;
	
EndFunction 

// Checks if there are references to objects in the data base.
//
// Parameters:
//  Ref       - AnyRef
//               - Values array of the AnyRef type.
//
//  SearchInServiceObjects - Boolean - initial value
//                 False when True is set, then exceptions
//                 of refs search set when the configuration is developed will not be considered.
//
//  OtherExceptions - Array of metadata objects full names
//                 that should be excluded from the refs search.
//
// Returns:
//  Boolean.
//
Function ThereAreRefsToObject(Val RefOrRefArray, Val SearchInServiceObjects = False,  OtherExceptions = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(RefOrRefArray) = Type("Array") Then
		RefArray = RefOrRefArray;
	Else
		RefArray = New Array;
		RefArray.Add(RefOrRefArray);
	EndIf;
	
	RefsTable = FindByRef(RefArray);
	RefsTable.Columns[0].Name = "SourceRef";
	RefsTable.Columns[1].Name = "FoundReference";
	RefsTable.Columns[2].Name = "FindMetadata";
	
	If Not SearchInServiceObjects Then
		RefsSearchExceptions = GetOverallRefSearchExceptionList();
		Exceptions = New Array;
		
		For Each TableRow In RefsTable Do
			ExceptSearch = RefsSearchExceptions[TableRow.FindMetadata];
			If ExceptSearch = "*" Then
				Exceptions.Add(TableRow);
			EndIf;
		EndDo;
		
		For Each TableRow In Exceptions Do
			RefsTable.Delete(TableRow);
		EndDo;
	EndIf;
	
	If TypeOf(OtherExceptions) = Type("Array") Then
		RefsSearchExceptions = New Map;
		Exceptions = New Array;
		
		For Each FullName In OtherExceptions Do
			MetadataObject = Metadata.FindByFullName(FullName);
			If MetadataObject <> Undefined Then
				RefsSearchExceptions.Insert(MetadataObject, "*");
			EndIf;
		EndDo;
		
		For Each TableRow In RefsTable Do
			ExceptSearch = RefsSearchExceptions[TableRow.FindMetadata];
			If ExceptSearch = "*" Then
				Exceptions.Add(TableRow);
			EndIf;
		EndDo;
		
		For Each TableRow In Exceptions Do
			RefsTable.Delete(TableRow);
		EndDo;
	EndIf;
	
	Return RefsTable.Count() > 0;
	
EndFunction

// Replaces references in all data. Unused references are optionally removed after replacement.
// References are replaced with transactions by the changed object and its links not by the analyzed reference.
//
// Parameters:
//
//     SubstitutionsPairs - Map - Key - search reference, Value - ref for replacement. Refs to themselves and
// empty refs for search will be ignored.
//
//     Parameters - Structure    - Replacement parameters. May include fields:
//
//                                * RemovalMethod - String, marker of the deletion method. It can take values:
//                                      "Directly" - If after replacement the ref is
//                                                          not used anywhere, then it
//                                      will be deleted immediately "Markup"         - If after replacement the ref is
// not used, then it will be marked for deletion.
//                                      Any other values cancel the need for removal.
//                                      Value by default - empty row.
//
//                                * EnableBusinessLogic  - Boolean, check box of need
//                                                          to enable business logic during the objects writing.
//                                                          Value by default - True.
//
//                                * PairReplacementInTransaction - Boolean - if the value is True,
//                                                                   transaction spans all replacements for one pair of refs.
//                                                          False - each replacement of ref in one
//                                                                 object is executed in a separate transaction.
//                                                          Value by default - True.
//
//                                * PrivilegedRecord - Boolean - If the value is True,
//                                                                     the write is executed in the exclusive mode, else - with
//                                                                     the current rights.
//                                                            Value by default - False.
//
// Returns - ValueTable - description of failed replacements (errors) with columns:
//
//     * Ref - AnyRef - Reference that was replaced.
//     * ErrorObject - Arbitrary - Object - reason for error.
//     * ObjectErrorPresentation - String - String presentation of error object.
//     * ErrorType - String - Error type marker. Possible variants:
//                             LockError  - during reference processing some objects
//                             were locked DataChanged    - during processing the data was changed
//                             by another user WriteError      - failed to write an object, or
//                                                   the ItemsReplacePossibility method returned denial.
//                             RemovalError    - UnknownData
//                             failed to be deleted - during the processor the data
//                                                   was found that were not planned to be analyzed, exchange is not implemented.
//     * ErrorText - String - Detail error description.
//
Function ReplaceRefs(Val SubstitutionsPairs, Val Parameters = Undefined) Export
	
	// Defaults
	ReplacementParameters = New Structure;
	ReplacementParameters.Insert("DeleteDirectly",  False); 
	ReplacementParameters.Insert("MarkToDelete",      False); 
	ReplacementParameters.Insert("ControlOnWrite",       True); 
	ReplacementParameters.Insert("PrivilegedRecord", False);
	
	LongTransaction = True;
	
	If Parameters <> Undefined Then
		ParameterValue = Undefined;
		
		If Parameters.Property("RemovalMethod", ParameterValue) Then
			If ParameterValue = "Directly" Then
				ReplacementParameters.DeleteDirectly = True;
				ReplacementParameters.MarkToDelete     = False;
			ElsIf ParameterValue = "Check" Then
				ReplacementParameters.DeleteDirectly = False;
				ReplacementParameters.MarkToDelete     = True;
			EndIf;
		EndIf;
		
		If Parameters.Property("EnableBusinessLogic", ParameterValue) Then
			If ParameterValue = True Then
				ReplacementParameters.ControlOnWrite = True;
			ElsIf ParameterValue = False Then
				ReplacementParameters.ControlOnWrite = False;
			EndIf;
		EndIf;
		
		If Parameters.Property("PairReplacementInTransaction", ParameterValue) Then
			If ParameterValue = True Then
				LongTransaction = True;
			ElsIf ParameterValue = False Then
				LongTransaction = False;
			EndIf;
		EndIf;
		
		If Parameters.Property("PrivilegedRecord", ParameterValue) Then
			If ParameterValue = True Then
				ReplacementParameters.PrivilegedRecord = True;
			ElsIf ParameterValue = False Then
				ReplacementParameters.PrivilegedRecord = False;
			EndIf;
		EndIf;
		
	EndIf;
	
	StringType = New TypeDescription("String");

	ReplacementResult = New ValueTable;
	ReplacementResult.Columns.Add("Ref");
	ReplacementResult.Columns.Add("ErrorObject");
	ReplacementResult.Columns.Add("ErrorObjectPresentation", StringType);
	ReplacementResult.Columns.Add("ErrorType", StringType);
	ReplacementResult.Columns.Add("ErrorText", StringType);
	ReplacementResult.Indexes.Add("Ref");
	ReplacementResult.Indexes.Add("Ref, ErrorObject, ErrorType");
	
	If SubstitutionsPairs.Count() = 0 Then
		Return ReplacementResult;
	EndIf;
	
	If ReplacementParameters.ControlOnWrite AND SubsystemExists("StandardSubsystems.SearchAndDeleteDuplicates") Then
		ModuleSearchAndDeleteDuplicates = CommonModule("SearchAndDeleteDuplicates");
		Errors = ModuleSearchAndDeleteDuplicates.CheckReplacementElementsPossibility(SubstitutionsPairs, Parameters);
		If Errors.Count() > 0 Then
			For Each KeyValue In Errors Do
				What = KeyValue.Key;
				ForWhat = SubstitutionsPairs[What];
				ErrorText = KeyValue.Value;
				Cause = ReplacementErrorDescription("RecordingError", ForWhat, SubjectString(ForWhat), ErrorText);
				AddReplacementResult(ReplacementResult, What, Cause);
			EndDo;
			For Each KeyValue In SubstitutionsPairs Do
				If Errors[KeyValue.Key] = Undefined Then
					What = KeyValue.Key;
					ForWhat = KeyValue.Value;
					ErrorText = NStr("en='Not replaced due to the previous issues.';ru='Замена не была выполнена из-за предыдущих проблем.'");
					Cause = ReplacementErrorDescription("RecordingError", ForWhat, SubjectString(ForWhat), ErrorText);
					AddReplacementResult(ReplacementResult, What, Cause);
				EndIf;
			EndDo;
			Return ReplacementResult;
		EndIf;
	EndIf;
	
	MetadataCache = New Map;
	
	RefsList = New Array;
	For Each KeyValue In SubstitutionsPairs Do
		CurrentRef = KeyValue.Key;
		TargetRef = KeyValue.Value;
		
		If CurrentRef = TargetRef Or CurrentRef.IsEmpty() Then
			// Ref to yourself and empty references do not replace.
			Continue;
		EndIf;
		
		RefsList.Add(CurrentRef);
	EndDo;
	
	SearchTable = UsagePlaces(RefsList);
	
	// For each object reference replacements will be executed in the following order "constant" "Object" "Set".
	// Concurrent empty row in this column - check box showing that this replacement is not needed or is already executed.
	SearchTable.Columns.Add("ReplacementKey", StringType);
	SearchTable.Indexes.Add("Ref, ReplacementKey");
	SearchTable.Indexes.Add("Data, ReplacementKey");
	
	// Auxiliary data
	SearchTable.Columns.Add("TargetRef");
	
	Configuration = New Structure;
	Configuration.Insert("AllRefsType",   TypeDescriptionAllReferences() );
	Configuration.Insert("MetaConstants",  Metadata.Constants);
	Configuration.Insert("TypeRecordKey",  TypeDescriptionRecordsKeys() );
	
	// Define the order of processor and check what can be processed.
	ExecutedReplacements = New Array;
	For Each CurrentRef In RefsList Do
		TargetRef = SubstitutionsPairs[CurrentRef];
		
		MarkupResult = Undefined; 
		PlaceUsagePlaces(Configuration, CurrentRef, TargetRef, SearchTable, MarkupResult);
		
		If MarkupResult.MarkupErrors.Count() = 0 Then
			ExecutedReplacements.Add(CurrentRef);
			
		Else
			// Unknown replacement types are found, do not work with this reference,  coherency violation is possible.
			For Each Error In MarkupResult.MarkupErrors Do
				ErrorObjectPresentation = SubjectString(Error.Object);
				AddReplacementResult(ReplacementResult, CurrentRef, 
					ReplacementErrorDescription("UnknownData", Error.Object, ErrorObjectPresentation, Error.Text));
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If LongTransaction Then
		For Each Ref In ExecutedReplacements Do
			ReplaceRefWithLongTransaction(ReplacementResult, Ref, ReplacementParameters, SearchTable);
		EndDo;
	Else
		ReplaceRefsWithShortTransactions(ReplacementResult, ReplacementParameters, ExecutedReplacements, SearchTable);
	EndIf;
	
	Return ReplacementResult;
EndFunction

// Receives all references usage places.
// If any reference is not used anywhere, then there will be no rows for it in the resulting table.
// 
// Parameters:
//     RefsSet     - Array - References for which search for usage places.
//     ResultAddress - String - Optional address in the temporary storage where the
//                                copy of the replacement result will be put.
// 
// Returns:
//     ValueTable - Consists of columns:
//       * Ref                - AnyRef      - Ref that is analyzed.
//       *Data                - Arbitrary     - Data containing the analyzed reference.
//       * Metadata            - MetadataObject - Metadata of the found data.
//       * DataPresentation   - String           - Data presentation containing analyzed reference.
//       * RefType             - Type              - Type of the analyzed reference.
//       * AuxiliaryData - Boolean           - True if data is used
//                                                    by the analyzed ref as helper data (leading dimension and etc.).
//
Function UsagePlaces(Val RefsSet, Val ResultAddress = "") Export
	
	UsagePlaces = New ValueTable;
	
	SetPrivilegedMode(True);
	UsagePlaces = FindByRef(RefsSet);
	
	UsagePlaces.Columns.Add("DataPresentation", New TypeDescription("String"));
	UsagePlaces.Columns.Add("ReferenceType");
	UsagePlaces.Columns.Add("AuxiliaryData", New TypeDescription("Boolean"));
	
	UsagePlaces.Indexes.Add("Ref");
	UsagePlaces.Indexes.Add("Data");
	UsagePlaces.Indexes.Add("AuxiliaryData");
	UsagePlaces.Indexes.Add("Ref, AuxiliaryData");
	
	TypeRecordsKeys = TypeDescriptionRecordsKeys();
	AllRefsType    = TypeDescriptionAllReferences();
	
	MetaSequences = Metadata.Sequences;
	MetaConstants          = Metadata.Constants;
	MetaDocuments          = Metadata.Documents;
	
	HelperMetadata = GetOverallRefSearchExceptionList();
	
	DimensionsCache = New Map;
	
	For Each String In UsagePlaces Do
		Ref    = String.Ref;
		Data    = String.Data;
		Meta      = String.Metadata;
		DataType = TypeOf(Data);
		
		AuxiliaryDataPath = HelperMetadata[Meta];
		
		If AuxiliaryDataPath = Undefined Then
			IsAuxiliaryData = (Ref = Data);
			
		ElsIf AuxiliaryDataPath = "*" Then
			IsAuxiliaryData = True;
			
		ElsIf TypeRecordsKeys.ContainsType(DataType) Then
			IsAuxiliaryData = False;
			For Each StringData In Data Do
				If Ref = EvaluateDataValueByPath(StringData, AuxiliaryDataPath) Then
					IsAuxiliaryData = True;
					Break;
				EndIf;
			EndDo;
			
		Else
			IsAuxiliaryData = (Ref = EvaluateDataValueByPath(Data, AuxiliaryDataPath) );
			
		EndIf;
		
		If MetaDocuments.Contains(Meta) Then
			Presentation = String(Data);
			
		ElsIf MetaConstants.Contains(Meta) Then
			Presentation = Meta.Presentation() + " (" + NStr("en='constant';ru='постоянная'") + ")";
			
		ElsIf MetaSequences.Contains(Meta) Then
			Presentation = Meta.Presentation() + " (" + NStr("en='sequence';ru='последовательность'") + ")";
			
		ElsIf DataType = Undefined Then
			Presentation = String(Data);
			
		ElsIf AllRefsType.ContainsType(DataType) Then
			MetaObjectPresentation = New Structure("ObjectPresentation");
			FillPropertyValues(MetaObjectPresentation, Meta);
			If IsBlankString(MetaObjectPresentation.ObjectPresentation) Then
				MetaPresentation = Meta.Presentation();
			Else
				MetaPresentation = MetaObjectPresentation.ObjectPresentation;
			EndIf;
			Presentation = String(Data);
			If Not IsBlankString(MetaPresentation) Then
				Presentation = Presentation + " (" + MetaPresentation + ")";
			EndIf;
			
		ElsIf TypeRecordsKeys.ContainsType(DataType) Then
			Presentation = Meta.RecordPresentation;
			If IsBlankString(Presentation) Then
				Presentation = Meta.Presentation();
			EndIf;
			
			DimensionsDescription = "";
			For Each KeyValue In SetDimensionsDescription(Meta, DimensionsCache) Do
				Value = Data[KeyValue.Key];
				Definition = KeyValue.Value;
				If Value = Ref Then
					If Definition.Master Then
						IsAuxiliaryData = True;
					EndIf;
				EndIf;
				Format = Definition.Format; 
				DimensionsDescription = DimensionsDescription + ", " 
					+ Definition.Presentation + " """ + ?(Format = Undefined, String(Value), Format(Value, Format)) + """";
			EndDo;
			DimensionsDescription = Mid(DimensionsDescription, 3);
			
			If Not IsBlankString(DimensionsDescription) Then
				Presentation = Presentation + " (" + DimensionsDescription + ")";
			EndIf;
			
		Else
			Presentation = String(Data);
			
		EndIf;
		
		String.DataPresentation   = Presentation;
		String.AuxiliaryData = IsAuxiliaryData;
		String.ReferenceType             = TypeOf(String.Ref);
	EndDo;
	
	If Not IsBlankString(ResultAddress) Then
		PutToTempStorage(UsagePlaces, ResultAddress);
	EndIf;
	
	Return UsagePlaces;
EndFunction

// Outdated. You should use SearchAndDeleteDuplicates.FindItemDuplicates.
//
Function FindItemDuplicates(Val SearchArea, Val ReferenceObject, Val AdditionalParameters) Export
	
	If SubsystemExists("StandardSubsystems.SearchAndDeleteDuplicates") Then
		ModuleSearchAndDeleteDuplicates = CommonModule("SearchAndDeleteDuplicates");
		Return ModuleSearchAndDeleteDuplicates.FindItemDuplicates(SearchArea, ReferenceObject, AdditionalParameters);
	EndIf;
	
EndFunction

// Returns type description including all possible reference configuration types.
//
Function TypeDescriptionAllReferences() Export
	
	Return New TypeDescription(New TypeDescription(New TypeDescription(New TypeDescription(New TypeDescription(
		New TypeDescription(New TypeDescription(New TypeDescription(New TypeDescription(
			   Catalogs.AllRefsType(),
			   Documents.AllRefsType().Types()
			), ExchangePlans.AllRefsType().Types()
			), Enums.AllRefsType().Types()
			), ChartsOfCharacteristicTypes.AllRefsType().Types()
			), ChartsOfAccounts.AllRefsType().Types()
			), ChartsOfCalculationTypes.AllRefsType().Types()
			), BusinessProcesses.AllRefsType().Types()
			), BusinessProcesses.RoutePointsAllRefsType().Types()
			), Tasks.AllRefsType().Types()
		);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions for work with applied types and values collections.

// Receives the enumeration value name as metadata object.
//
// Parameters:
//  Value - enumeration value for which it is required to receive enumeration name.
//
// Returns:
//  String - enumeration value name as metadata object.
//
Function NameOfEnumValue(Value) Export
	
	MetadataObject = Value.Metadata();
	
	ValueIndex = Enums[MetadataObject.Name].IndexOf(Value);
	
	Return MetadataObject.EnumValues[ValueIndex].Name;
	
EndFunction 

// Fills in the array-receiver with the unique values from the array-source.
// If an item in array-receiver already exists, then new item is not added.
//
// Parameters:
//  ArrayReceiver - Array - array that is filled in with unique values.
//  ArraySource - Array - array from which items are selected to the array-recipient.
// 
Procedure FillArrayWithUniqueValues(ArrayReceiver, ArraySource) Export
	
	UniqueValues = New Map;
	
	For Each Value In ArrayReceiver Do
		UniqueValues.Insert(Value, True);
	EndDo;
	
	For Each Value In ArraySource Do
		If UniqueValues[Value] = Undefined Then
			ArrayReceiver.Add(Value);
			UniqueValues.Insert(Value, True);
		EndIf;
	EndDo;
	
EndProcedure

// Procedure deletes from the AttributesArray items corresponding to the names of the object attributes from the UncheckedAttributesArray array.
// To use in the handler of the FillCheckProcessing event.
//
// Parameters:
// AttributeArray              - Array - Strings array is with object attributes names.
// NoncheckableAttributeArray - Strings array with objects attributes names that do not require check.
//
Procedure DeleteUnverifiableAttributesFromArray(AttributeArray, NoncheckableAttributeArray) Export
	
	For Each ArrayElement In NoncheckableAttributeArray Do
	
		SequenceNumber = AttributeArray.Find(ArrayElement);
		If SequenceNumber <> Undefined Then
			AttributeArray.Delete(SequenceNumber);
		EndIf;
	
	EndDo;
	
EndProcedure

//	Converts the value table to array.
//	It can be used to transfer client
//	the data received on the server as a value table only
//	if the value table contains only the
//	values that can be transferred to the client.
//
//	Received array contains structures at that
//	each structure repeats the structure of the value table columns.
//
//	It is not recommended to use
//	to convert value tables with a large number of strings.
//
//	Parameters: 
//	   ValueTable - ValueTable
//
//	Returns: 
//	   Array
//
Function ValueTableToArray(ValueTable) Export
	
	Array = New Array();
	StructureString = "";
	CommaRequired = False;
	For Each Column In ValueTable.Columns Do
		If CommaRequired Then
			StructureString = StructureString + ",";
		EndIf;
		StructureString = StructureString + Column.Name;
		CommaRequired = True;
	EndDo;
	For Each String In ValueTable Do
		NewRow = New Structure(StructureString);
		FillPropertyValues(NewRow, String);
		Array.Add(NewRow);
	EndDo;
	Return Array;

EndFunction

// Function ValuesTableRowToStructure
// creates a structure with properties like
// values table columns
// of the passed rows and
// sets the values of these properties from the values table row.
// 
// Parameters:
//  ValueTableRow - ValueTableRow
//
// ReturnValue:
//  Structure
//
Function ValueTableRowToStructure(ValueTableRow) Export
	
	Structure = New Structure;
	For Each Column In ValueTableRow.Owner().Columns Do
		Structure.Insert(Column.Name, ValueTableRow[Column.Name]);
	EndDo;
	
	Return Structure;
	
EndFunction

// Creates a structure similar to a manager of information register record.
// 
// Parameters:
// RecordManager - InformationRegisterRecordManager,
// RegisterMetadata - information register metadata.
//
Function StructureByRecordManager(RecordManager, RegisterMetadata) Export
	
	RecordAsStructure = New Structure;
	
	If RegisterMetadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		RecordAsStructure.Insert("Period", RecordManager.Period);
	EndIf;
	For Each Field In RegisterMetadata.Dimensions Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	For Each Field In RegisterMetadata.Resources Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	For Each Field In RegisterMetadata.Attributes Do
		RecordAsStructure.Insert(Field.Name, RecordManager[Field.Name]);
	EndDo;
	
	Return RecordAsStructure;
	
EndFunction

// Creates array and copies there values that are contained in the rows collection column.
//
// Parameters:
// RowCollection - collection for which the bypass via the For Each … operator is available From ... Cycle.
// ColumnName - String with collection name field values of which should be exported.
// UniqueValuesOnly - Boolean, optional if True, then only distinct values will be included to the array.
//
Function UnloadColumn(RowCollection, ColumnName, UniqueValuesOnly = False) Export

	ValueArray = New Array;
	
	UniqueValues = New Map;
	
	For Each CollectionRow In RowCollection Do
		Value = CollectionRow[ColumnName];
		If UniqueValuesOnly AND UniqueValues[Value] <> Undefined Then
			Continue;
		EndIf;
		ValueArray.Add(Value);
		UniqueValues.Insert(Value, True);
	EndDo; 
	
	Return ValueArray;
	
EndFunction

// It converts an XML text to
// the value table, the table columns are created based on the description in XML.
//
// Parameters:
//  XML     - text in XML or ReadXML format.
//
// XML schema:
// <?xml version="1.0"
//  encoding="utf-8"?> <xs:schema attributeFormDefault="unqualified" elementFormDefault="qualified"
//  xmlns:xs="http://www.w3.org/2001/XMLSchema"> <xs:element
//  name="Items"> <xs:complexType>
//  <xs:sequence>
//  <xs:element maxOccurs="unbounded" name="Item">
//  <xs:complexType>
//  <xs:attribute name="Code" type="xs:integer" use="required" /> <xs:attribute
//  name="Name" type="xs:string" use="required" /> <xs:attribute
//  name="Socr" type="xs:string" use="required" /> <xs:attribute name="Index"
//  type="xs:string" use="required" /> </xs:complexType> </xs:element>
//  </xs:sequence> <xs:attribute
//  name="Description"
//  type="xs:string"
//  use="required" /> <xs:attribute name="Columns" type="xs:string"
//  use="required" /> </xs:complexType> </xs:element> </xs:schema>
//
// Examples of XML files, see in the sample configuration.
// 
// Useful example:
//   ClassifierTable = ReadXMLToTable (DataRegisters.AddressClassifier.
//       GetTemplate("RussiaAddressObjectsClassifier").GetText());
//
// Returns:
//  Structure - with fields
// * TableName - String
//    * Data - ValuesTable.
//
Function ReadXMLToTable(Val XML) Export
	
	If TypeOf(XML) <> Type("XMLReader") Then
		Read = New XMLReader;
		Read.SetString(XML);
	Else
		Read = XML;
	EndIf;
	
	// Read the first node and check it.
	If Not Read.Read() Then
		Raise NStr("en='Empty XML';ru='Пустой XML'");
	ElsIf Read.Name <> "Items" Then
		Raise NStr("en='An error occurred in XML structure';ru='Ошибка в структуре XML'");
	EndIf;
	
	// Get the table description and create it.
	TableName = Read.GetAttribute("Description");
	ColumnNames = StrReplace(Read.GetAttribute("Columns"), ",", Chars.LF);
	Columns = StrLineCount(ColumnNames);
	
	ValueTable = New ValueTable;
	For Ct = 1 To Columns Do
		ValueTable.Columns.Add(StrGetLine(ColumnNames, Ct), New TypeDescription("String"));
	EndDo;
	
	// Fill in the values in the table.
	While Read.Read() Do
		
		If Read.NodeType = XMLNodeType.EndElement AND Read.Name = "Items" Then
			Break;
		ElsIf Read.NodeType <> XMLNodeType.StartElement Then
			Continue;
		ElsIf Read.Name <> "Item" Then
			Raise NStr("en='An error occurred in XML structure';ru='Ошибка в структуре XML'");
		EndIf;
		
		NewRow = ValueTable.Add();
		For Ct = 1 To Columns Do
			ColumnName = StrGetLine(ColumnNames, Ct);
			NewRow[Ct-1] = Read.GetAttribute(ColumnName);
		EndDo;
		
	EndDo;
	
	// Fill in the result
	Result = New Structure;
	Result.Insert("TableName", TableName);
	Result.Insert("Data", ValueTable);
	
	Return Result;
	
EndFunction

// Function compares two strings collections for which the bypass using the For each ... operator is available. From ... Cycle.
// Compared collections should meet the following requirements:
// - the bypass via the For each operator … is available From ... Cycle,
// - presence of all columns in both collections listed in
// the ColumnsNames parameter (if ColumnsNames is not filled in - all columns).
//
// Parameters:
// RowsCollection1 - CollectionValues - collection that meets the requirements listed above;
// RowsCollection2 - CollectionValues - collection that meets the requirements listed above;
// ColumnNames - String - columns names separated by commas according to which comparison is executed. 
// 					It is optional for collections the columns content of which can be identified: 
// 					ValuesTable, ValuesList, Map,
// 					Structure if it is not specified - compare in all columns.
// 					For the collection of other types is mandatory.
// ExcludingColumns - String - names of the columns that are ignored during comparison, optional.
// IncludingRowOrder - Boolean - if True, then the collections are considered to be identical only if the same rows are located on the same places in collections.
//
// Returns:
//  Boolean.
//
Function IdenticalCollections(RowsCollection1, RowsCollection2, ColumnNames = "", ExcludingColumns = "", IncludingRowOrder = False) Export
	
	// Collections types for which columns content is available and you can find out whether it is specified.
	SpecialCollectionTypes = New Array;
	SpecialCollectionTypes.Add(Type("ValueTable"));
	SpecialCollectionTypes.Add(Type("ValueList"));
	
	KeyAndValueCollectionTypes = New Array;
	KeyAndValueCollectionTypes.Add(Type("Map"));
	KeyAndValueCollectionTypes.Add(Type("Structure"));
	KeyAndValueCollectionTypes.Add(Type("FixedMap"));
	KeyAndValueCollectionTypes.Add(Type("FixedStructure"));
	
	If IsBlankString(ColumnNames) Then
		If SpecialCollectionTypes.Find(TypeOf(RowsCollection1)) <> Undefined 
			Or KeyAndValueCollectionTypes.Find(TypeOf(RowsCollection1)) <> Undefined Then
			ColumnsToCompare = New Array;
			If TypeOf(RowsCollection1) = Type("ValueTable") Then
				For Each Column In RowsCollection1.Columns Do
					ColumnsToCompare.Add(Column.Name);
				EndDo;
			ElsIf TypeOf(RowsCollection1) = Type("ValueList") Then
				ColumnsToCompare.Add("Value");
				ColumnsToCompare.Add("Picture");
				ColumnsToCompare.Add("Check");
				ColumnsToCompare.Add("Presentation");
			ElsIf KeyAndValueCollectionTypes.Find(TypeOf(RowsCollection1)) <> Undefined Then
				ColumnsToCompare.Add("Key");
				ColumnsToCompare.Add("Value");
			EndIf;
		Else
			ErrorMessage = NStr("en='Specify names of fields for comparison for the collection of type %1';ru='Для коллекции типа %1 необходимо указать имена полей, по которым производится сравнение'");
			Raise StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, TypeOf(RowsCollection1));
		EndIf;
	Else
		ColumnsToCompare = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ColumnNames);
	EndIf;

	// Subtract the excluded fields
	ColumnsToCompare = CommonUseClientServer.ReduceArray(ColumnsToCompare, 
						StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ExcludingColumns));
						
	If IncludingRowOrder Then
		
		// Parallel bypass of both collections.
		CollectionLineNumber1 = 0;
		For Each CollectionRow1 In RowsCollection1 Do
			// Position to the analogical row of the second collection.
			CollectionLineNumber2 = 0;
			HasCollectionRows2 = False;
			For Each CollectionRow2 In RowsCollection2 Do
				HasCollectionRows2 = True;
				If CollectionLineNumber2 = CollectionLineNumber1 Then
					Break;
				EndIf;
				CollectionLineNumber2 = CollectionLineNumber2 + 1;
			EndDo;
			If Not HasCollectionRows2 Then
				// There are no rows at all in the second collection.
				Return False;
			EndIf;
			// Compare fields values of two rows.
			For Each ColumnName In ColumnsToCompare Do
				If CollectionRow1[ColumnName] <> CollectionRow2[ColumnName] Then
					Return False;
				EndIf;
			EndDo;
			CollectionLineNumber1 = CollectionLineNumber1 + 1;
		EndDo;
		
		CollectionRowCount1 = CollectionLineNumber1;
		
		// Calculate the quantity of rows in the second collection separately.
		CollectionRowCount2 = 0;
		For Each CollectionRow2 In RowsCollection2 Do
			CollectionRowCount2 = CollectionRowCount2 + 1;
		EndDo;
		
		// If there are no rows in the first collection, there should be no rows in the second one.
		If CollectionRowCount1 = 0 Then
			For Each CollectionRow2 In RowsCollection2 Do
				Return False;
			EndDo;
			CollectionRowCount2 = 0;
		EndIf;
		
		// Rows quantity should not differ.
		If CollectionRowCount1 <> CollectionRowCount2 Then
			Return False;
		EndIf;
		
	Else
	
		// Check the identity of the same rows content without considering their sequence.
		
		// Accumulate selection rows by the first collection in order to:
		//  - do not search for the similar rows again,
		//  - make sure the second collection contains no row that the accumulated ones do not contain.
		
		FilterRows = New ValueTable;
		FilterParameters = New Structure;
		For Each ColumnName In ColumnsToCompare Do
			FilterRows.Columns.Add(ColumnName);
			FilterParameters.Insert(ColumnName);
		EndDo;
		
		HasCollectionRows1 = False;
		For Each FilterRow In RowsCollection1 Do
			
			FillPropertyValues(FilterParameters, FilterRow);
			If FilterRows.FindRows(FilterParameters).Count() > 0 Then
				// Row with such fields was already searched for.
				Continue;
			EndIf;
			FillPropertyValues(FilterRows.Add(), FilterRow);
			
			// Calculate the quantity of such rows in the first collection.
			CollectionRowsFound1 = 0;
			For Each CollectionRow1 In RowsCollection1 Do
				RowFits = True;
				For Each ColumnName In ColumnsToCompare Do
					If CollectionRow1[ColumnName] <> FilterRow[ColumnName] Then
						RowFits = False;
						Break;
					EndIf;
				EndDo;
				If RowFits Then
					CollectionRowsFound1 = CollectionRowsFound1 + 1;
				EndIf;
			EndDo;
			
			// Calculate the quantity of such rows in the second collection.
			CollectionRowsFound2 = 0;
			For Each CollectionRow2 In RowsCollection2 Do
				RowFits = True;
				For Each ColumnName In ColumnsToCompare Do
					If CollectionRow2[ColumnName] <> FilterRow[ColumnName] Then
						RowFits = False;
						Break;
					EndIf;
				EndDo;
				If RowFits Then
					CollectionRowsFound2 = CollectionRowsFound2 + 1;
					// If there are more such rows in the second collection than in the first one, then it concludes that the collections are not identical.
					If CollectionRowsFound2 > CollectionRowsFound1 Then
						Return False;
					EndIf;
				EndIf;
			EndDo;
			
			// Quantity of such rows must not differ.
			If CollectionRowsFound1 <> CollectionRowsFound2 Then
				Return False;
			EndIf;
			
			HasCollectionRows1 = True;
			
		EndDo;
		
		// If there are no rows in the first collection, there should be no rows in the second one.
		If Not HasCollectionRows1 Then
			For Each CollectionRow2 In RowsCollection2 Do
				Return False;
			EndDo;
		EndIf;
		
		// Check if the second collection contains no row that the accumulated ones do not contain.
		For Each CollectionRow2 In RowsCollection2 Do
			FillPropertyValues(FilterParameters, CollectionRow2);
			If FilterRows.FindRows(FilterParameters).Count() = 0 Then
				Return False;
			EndIf;
		EndDo;
	
	EndIf;
	
	Return True;
	
EndFunction

// Compares data of a complex structure considering the nesting.
//
// Parameters:
//  Data1 - Structure, FixedStructure -
//          - Map, FixedMatch -
//          - Array,       FixedArray - 
//          - ValueStorage, ValuesTable -
//          - Simple types - that can be compared
//            to equal, for example, String, Number, Boolean.
//
//  Data2 - Arbitrary - the same types as for the Data1 parameter.
//
// Returns:
//  Boolean.
//
Function DataMatch(Data1, Data2) Export
	
	If TypeOf(Data1) <> TypeOf(Data2) Then
		Return False;
	EndIf;
	
	If TypeOf(Data1) = Type("Structure")
	 OR TypeOf(Data1) = Type("FixedStructure") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		For Each KeyAndValue In Data1 Do
			OldValue = Undefined;
			
			If Not Data2.Property(KeyAndValue.Key, OldValue)
			 OR Not DataMatch(KeyAndValue.Value, OldValue) Then
			
				Return False;
			EndIf;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("Map")
	      OR TypeOf(Data1) = Type("FixedMap") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		NewMappingKeys = New Map;
		
		For Each KeyAndValue In Data1 Do
			NewMappingKeys.Insert(KeyAndValue.Key, True);
			OldValue = Data2.Get(KeyAndValue.Key);
			
			If Not DataMatch(KeyAndValue.Value, OldValue) Then
				Return False;
			EndIf;
		EndDo;
		
		For Each KeyAndValue In Data2 Do
			If NewMappingKeys[KeyAndValue.Key] = Undefined Then
				Return False;
			EndIf;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("Array")
	      OR TypeOf(Data1) = Type("FixedArray") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		IndexOf = Data1.Count()-1;
		While IndexOf >= 0 Do
			If Not DataMatch(Data1.Get(IndexOf), Data2.Get(IndexOf)) Then
				Return False;
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("ValueTable") Then
		
		If Data1.Count() <> Data2.Count() Then
			Return False;
		EndIf;
		
		If Data1.Columns.Count() <> Data2.Columns.Count() Then
			Return False;
		EndIf;
		
		For Each Column In Data1.Columns Do
			If Data2.Columns.Find(Column.Name) = Undefined Then
				Return False;
			EndIf;
			
			IndexOf = Data1.Count()-1;
			While IndexOf >= 0 Do
				If Not DataMatch(Data1[IndexOf][Column.Name], Data2[IndexOf][Column.Name]) Then
					Return False;
				EndIf;
				IndexOf = IndexOf - 1;
			EndDo;
		EndDo;
		
		Return True;
		
	ElsIf TypeOf(Data1) = Type("ValueStorage") Then
	
		If Not DataMatch(Data1.Get(), Data2.Get()) Then
			Return False;
		EndIf;
		
		Return True;
	EndIf;
	
	Return Data1 = Data2;
	
EndFunction

// Records data of the Structure, Map, Array types considering nesting.
//
// Parameters:
//  Data - Structure, Map, Array - collections the values of
//           which are primitive types, the values storage or can not be changed. Values types are supported:
//           Boolean, String, Number, Date, Undefined, UUID,
//           Null, Type, ValueStorage, CommonModule, MetadataObject,
//           XDTOValueType, XDTOObjectType, AnyRef.
//
//  CallingException - Boolean - initial value is True. When set.
//                       False, then in case there is uncommittable data,
//                       the exception will not be thrown. The data will be recorded as well as possible.
//
// Returns:
//  Fixed data similar to the passed ones in the Data parameter.
// 
Function FixedData(Data, CallingException = True) Export
	
	If TypeOf(Data) = Type("Array") Then
		Array = New Array;
		
		IndexOf = Data.Count() - 1;
		
		For Each Value In Data Do
			
			If TypeOf(Value) = Type("Structure")
			 OR TypeOf(Value) = Type("Map")
			 OR TypeOf(Value) = Type("Array") Then
				
				Array.Add(FixedData(Value, CallingException));
			Else
				If CallingException Then
					CheckingDataFixed(Value, True);
				EndIf;
				Array.Add(Value);
			EndIf;
		EndDo;
		
		Return New FixedArray(Array);
		
	ElsIf TypeOf(Data) = Type("Structure")
	      OR TypeOf(Data) = Type("Map") Then
		
		If TypeOf(Data) = Type("Structure") Then
			Collection = New Structure;
		Else
			Collection = New Map;
		EndIf;
		
		For Each KeyAndValue In Data Do
			Value = KeyAndValue.Value;
			
			If TypeOf(Value) = Type("Structure")
			 OR TypeOf(Value) = Type("Map")
			 OR TypeOf(Value) = Type("Array") Then
				
				Collection.Insert(
					KeyAndValue.Key, FixedData(Value, CallingException));
			Else
				If CallingException Then
					CheckingDataFixed(Value, True);
				EndIf;
				Collection.Insert(KeyAndValue.Key, Value);
			EndIf;
		EndDo;
		
		If TypeOf(Data) = Type("Structure") Then
			Return New FixedStructure(Collection);
		Else
			Return New FixedMap(Collection);
		EndIf;
		
	ElsIf CallingException Then
		CheckingDataFixed(Data);
	EndIf;
	
	Return Data;
	
EndFunction

// Creates a copy of XDTO object.
//
// Parameters:
//  Factory - XDTOFactory - factory that created the source object.
//  Object  - XDTODataObject  - object copy of which should be created.
//
// Returns:
//  XDTODataObject - copy of the source XDTO object.
//
Function CopyXDTO(Val Factory, Val Object) Export
	
	Record = New XMLWriter;
	Record.SetString();
	Factory.WriteXML(Record, Object, , , , XMLTypeAssignment.Explicit);
	
	XMLPresentation = Record.Close();
	
	Read = New XMLReader;
	Read.SetString(XMLPresentation);
	
	Return Factory.ReadXML(Read, Object.Type());
	
EndFunction

// Returns XML presentation of the XDTO type.
//
// Parameters:
//  XDTOType - XDTOObjectType, XDTOValueType - type XDTO for the which it is required to receive.
//   XML presentation
//
// Returns:
//  String - XML presentation of XDTO type.
//
Function XDTOTypePresentation(XDTOType) Export
	
	Return XDTOSerializer.XMLString(New XMLExpandedName(XDTOType.NamespaceURI, XDTOType.Name))
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Mathematical procedures and functions.

// Executes the proportional distribution of amount according to the specified ratios.
//
// Parameters:
//  DistributedAmount - Number;
//  DistributionRatios - Array;
//  RoundingPrecision - Number.
//
// Returns:
//   Array - list of the distributed amounts.
//               In case you could not allocate (amount = 0, ratios quantity
//               = 0 or ratios total weight = 0), Undefined value is returned.
//
Function DistributeAmountProportionallyToFactors(Val DistributedAmount, DistributionRatios, Val Precision = 2) Export
	
	Return CommonUseClientServer.DistributeAmountProportionallyToFactors(DistributedAmount, DistributionRatios, Precision);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with external connection.

// Outdated. You should use CommonUseClientServer.COMConnectorName.
//
Function COMConnectorName() Export
	
	Return CommonUseClientServer.COMConnectorName();
	
EndFunction

// Returns CLSID of COM-class for work with 1C:Enterprise 8 via COM-connection.
//
// Parameters:
//  COMConnectorName - String - COM-class name for work with 1C:Enterprise 8 via COM-connection.
//
// Returns:
//  String - CLSID row presentation.
//
Function COMConnectorIdentifier(Val COMConnectorName) Export
	
	If COMConnectorName = "v83.COMConnector" Then
	
		Return "181E893D-73A4-4722-B61D-D604B3D67D47";
		
	EndIf;
	
	ErrorMessage = NStr("en='CLSID is not specified for class %1';ru='На задан CLSID для класса %1'");
	ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorMessage, COMConnectorName);
	Raise ErrorMessage;
	
EndFunction

// Outdated. You should use CommonUseClientServer.EstablishExternalConnection.
//
Function EstablishExternalConnection(Parameters, ErrorMessageString = "", ErrorAttachingAddIn = False) Export
	
	Return CommonUseClientServer.EstablishExternalConnection(Parameters, ErrorMessageString, ErrorAttachingAddIn);
	
EndFunction

// Outdated. You should use CommonUseClientServer.SetOuterBaseConnection.
//
Function InstallOuterDatabaseJoin(Parameters) Export
	
	Return CommonUseClientServer.InstallOuterDatabaseJoin(Parameters);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Defines the operation mode of the infobase. It can be file (True) or server (False).
// During checking InfobaseConnectionRow is used that can clearly be recognized.
//
// Parameters:
//  InfobaseConnectionString - String - parameter is
//                 used if it is required to check a connection string not of the current infobase.
//
// Returns:
//  Boolean.
//
Function FileInfobase(Val InfobaseConnectionString = "") Export
			
	If IsBlankString(InfobaseConnectionString) Then
		InfobaseConnectionString =  InfobaseConnectionString();
	EndIf;
	Return Find(Upper(InfobaseConnectionString), "FILE=") = 1;
	
EndFunction 

// Session parameters are made "Not set". 
// 
// Parameters: 
// ClearingParameters - String - names of the session parameters for clearing separated by ",".
// Exceptions          - String - session parameters names not designed for clearing separated by , .
//
Procedure ClearSessionParameters(ClearingParameters = "", Exceptions = "") Export
	
	ExceptionArray           = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Exceptions);
	ParametersForClearingArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ClearingParameters);
	
	If ParametersForClearingArray.Count() = 0 Then
		For Each SessionParameter In Metadata.SessionParameters Do
			If ExceptionArray.Find(SessionParameter.Name) = Undefined Then
				ParametersForClearingArray.Add(SessionParameter.Name);
			EndIf;
		EndDo;
	EndIf;
	
	IndexOf = ParametersForClearingArray.Find("ClientParametersOnServer");
	If IndexOf <> Undefined Then
		ParametersForClearingArray.Delete(IndexOf);
	EndIf;
	
	SessionParameters.Clear(ParametersForClearingArray);
	
EndProcedure

// Returns description of the subject as the text row.
// 
// Parameters:
//  SubjectRef  - AnyRef - an object of a reference type.
//
// Returns:
//   Row.
// 
Function SubjectString(SubjectRef) Export
	
	Result = "";
	
	EventHandlers = ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\WhenDefiningPresentationObject");
	
	For Each Handler In EventHandlers Do
		Handler.Module.WhenDefiningPresentationObject(SubjectRef, Result);
	EndDo;
	
	CommonUseOverridable.SetSubjectPresentation(SubjectRef, Result);
	
	If IsBlankString(Result) Then
		If SubjectRef = Undefined Or SubjectRef.IsEmpty() Then
			Result = NStr("en='not specified';ru='не задан'");
		ElsIf Metadata.Documents.Contains(SubjectRef.Metadata()) Then
			Result = String(SubjectRef);
		Else
			ObjectPresentation = SubjectRef.Metadata().ObjectPresentation;
			If IsBlankString(ObjectPresentation) Then
				ObjectPresentation = SubjectRef.Metadata().Presentation();
			EndIf;
			Result = StringFunctionsClientServer.SubstituteParametersInString(
				"%1 (%2)", String(SubjectRef), ObjectPresentation);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Generates a match for objects removal.
Function GetOverallRefSearchExceptionList() Export
	
	RefsSearchExceptions = New Map;
	
	ExceptionArray = New Array;
	EventHandlers = ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks");
	For Each Handler In EventHandlers Do
		Handler.Module.OnAddExceptionsSearchLinks(ExceptionArray);
	EndDo;
	AddRefSearchExclusions(RefsSearchExceptions, ExceptionArray);
	
	ExceptionArray = CommonUseOverridable.GetRefSearchExceptions();
	AddRefSearchExclusions(RefsSearchExceptions, ExceptionArray);
	
	ExceptionArray = New Array;
	CommonUseOverridable.OnAddExceptionsSearchLinks(ExceptionArray);
	AddRefSearchExclusions(RefsSearchExceptions, ExceptionArray);

	Return RefsSearchExceptions;
	
EndFunction

// Returns the value as an XML string.
// Only those objects can be converted to an XML string (serialized) for those it is stated in the description that they are being serialized.
//
// Parameters:
//   Value - Custom. Value that should be serialized to XML-string.
//
// Returns:
//   String - Value presentation XML string in a serialized form.
//
Function ValueToXMLString(Value) Export
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XDTOSerializer.WriteXML(XMLWriter, Value, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();
EndFunction

// Returns the value received from XML-string. 
// Only those objects can be received from an XML string for which it is stated in the description that they are being serialized.
//
// Parameters:
// XMLString - String of the value presentation in a serialized form.
//
// Returns:
// Value retrieved from the passed XML-string.
//
Function ValueFromXMLString(XMLString) Export
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLString);
	
	Return XDTOSerializer.ReadXML(XMLReader);
EndFunction

// Returns XML-presentation by XDTO-object.
//
// Parameters:
//  XDTODataObject - XDTODataObject  - object for which it is required to generate XML-presentation.
//  Factory    - XDTOFactory - factory using which it is required to generate XML-presentation.
//                             If parameter is not specified - XDTO global factory will be used.
//
// Returns: 
//   String - XML-presentation of XDTO-object.
//
Function ObjectXDTOInXMLString(Val XDTODataObject, Val Factory = Undefined) Export
	
	If CommonUseClientServer.DebugMode() Then
		XDTODataObject.Validate();
	Else
		ErrorInfo = Undefined;
		Try
			XDTODataObject.Validate();
		Except
			ErrorInfo = ErrorInfo();
		EndTry;
		If ErrorInfo <> Undefined Then
			WriteLogEvent(
				NStr("en='Standard subsystems';ru='Стандартные подсистемы'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				,
				DetailErrorDescription(ErrorInfo));
		EndIf;
	EndIf;
	
	If Factory = Undefined Then
		Factory = XDTOFactory;
	EndIf;
	
	Record = New XMLWriter();
	Record.SetString();
	Factory.WriteXML(Record, XDTODataObject, , , , XMLTypeAssignment.Explicit);
	
	Return Record.Close();
	
EndFunction

// Generates XDTO-object by XML-presentation.
//
// Parameters:
//  XMLString - String    - XML-presentation
//  of XDTO-object, Factory - XDTOFactory - factory using which XDTO-object should be generated.
//                          If parameter is not specified - XDTO global factory will be used.
//
// Returns: 
//   ObjectXDTO.
//
Function ObjectXDTOFromXMLRow(Val XMLString, Val Factory = Undefined) Export
	
	If Factory = Undefined Then
		Factory = XDTOFactory;
	EndIf;
	
	Read = New XMLReader();
	Read.SetString(XMLString);
	
	Return Factory.ReadXML(Read);
	
EndFunction

// Generates from the SearchString source a row for search data in a query.
//
// Parameters:
// SearchString - String - source row containing prohibited characters.
//
// Returns:
//  String - String prepared to search data in a query.
//
Function GenerateStringForSearchInQuery(Val SearchString) Export
	
	ResultingSearchString = SearchString;
	ResultingSearchString = StrReplace(ResultingSearchString, "~", "~~");
	ResultingSearchString = StrReplace(ResultingSearchString, "%", "~%");
	ResultingSearchString = StrReplace(ResultingSearchString, "_", "~_");
	ResultingSearchString = StrReplace(ResultingSearchString, "[", "~[");
	ResultingSearchString = StrReplace(ResultingSearchString, "-", "~-");
	
	Return ResultingSearchString;
	
EndFunction

// Function returns WSProxy object created with the passed parameters.
//
// Parameters:
//  WSDLAddress - String - wsdl location.
//  NamespaceURI - String - URI spaces of the web-service names.
//  ServiceName - String - service name.
//  EndpointName - String - if it is not specified, it is generated as <ServiceName>Soap.
//  UserName - String - user name for the website login.
//  Password - String - user's password.
//  Timeout - Number - timeout for operations executed via the received proxy.
//
// Returns:
//  WSProxy
//
Function WSProxy(Val WSDLAddress,
	Val NamespaceURI,
	Val ServiceName,
	Val EndpointName = "",
	Val UserName,
	Val Password,
	Val Timeout = 0,
	Val MakeTestCall = False) Export

	If MakeTestCall AND Timeout <> Undefined AND Timeout > 20 Then
		
		WSProxyPing = CommonUseReUse.WSProxy(
			WSDLAddress,
			NamespaceURI,
			ServiceName,
			EndpointName,
			UserName,
			Password,
			3);
		
		Try
			WSProxyPing.Ping();
		Except
			WriteLogEvent(NStr("en='WSProxy';ru='WSПрокси'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
		
	EndIf;
	
	Return CommonUseReUse.WSProxy(
		WSDLAddress,
		NamespaceURI,
		ServiceName,
		EndpointName,
		UserName,
		Password,
		Timeout);
	
EndFunction

// Defines whether the metadata object is available by functional options.
//
// Parameters:
//   MetadataObject - MetadataObject - checked metadata object.
//
// Returns: 
//  Boolean - True if object available.
//
Function MetadataObjectAvailableByFunctionalOptions(MetadataObject) Export
	Return CommonUseReUse.ObjectsByOptionsAvailability()[MetadataObject] <> False;
EndFunction

// Selects or clears the deletion markup for all objects that reference to the specified “object-owner”.
//
// Parameters:
//  Owner        - ExchangePlanRef, CatalogRef, DocumentRef - ref to object
//                    that is the "owner" in relation to the objects marked for deletion.
//
//  DeletionMark - Boolean - Shows that markup for deletion in all subordinate objects is selected/cleared.
//
Procedure SetDeletionMarkForSubordinatedObjects(Val Owner, Val DeletionMark) Export
	
	BeginTransaction();
	Try
		
		RefsList = New Array;
		RefsList.Add(Owner);
		Refs = FindByRef(RefsList);
		
		For Each Ref In Refs Do
			
			If ReferenceTypeValue(Ref[1]) Then
				
				Ref[1].GetObject().SetDeletionMark(DeletionMark);
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Try to execute the request in several attempts.
// Used to read outside the transaction of the frequently changed data.
// During the call in transaction, an error occurs.
//
// Parameters:
//  Query - Query - query that should be executed.
//
// Returns:
//  QueryResult - query result.
//
Function ExecuteQueryBeyondTransaction(Val Query) Export
	
	If TransactionActive() Then
		Raise(NStr("en='Transaction is active. Cannot execute a query outside the transaction.';ru='Транзакция активна. Выполнение запроса вне транзакции невозможно.'"));
	EndIf;
	
	AttemptCount = 0;
	
	Result = Undefined;
	While True Do
		Try
			Result = Query.Execute(); // Reading outside a transaction, error is possible.
			                                // Could not continue scan with NOLOCK due to
			                                // data movement in this case you need to try to read it again.
			Break;
		Except
			AttemptCount = AttemptCount + 1;
			If AttemptCount = 5 Then
				Raise;
			EndIf;
		EndTry;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the common parameters of basic functionality.
//
// Returns: 
//  Structure - structure with properties:
//      * PersonalSettingsFormName            - String - form name for editing personal settings.
//                                                           Previously defined
//                                                           in CommonUseOverridable.PersonalSettingsFormName.
//      *  MinimumRequiredPlatformVersion    - String - full number of the platform version for application start.
//                                                           ForExample, 8.3.4.365.
//                                                           Previously
//                                                           defined in CommonUseOverridable.GetMinRequiredPlatformVersion.
//      * WorkInParameterProhibited               - Boolean - Initial value is False.
//      * RequestApprovalOnApplicationEnd - Boolean - True by default. If you set False,
//                                                                  then the approval during the application
//                                                                  shutdown will not be requested if you do
//                                                                  not allow it in personal application settings.
//      * DisableCatalogMetadataObjectsIDs - Boolean - disables catalog filling.
//              MetadataObjectsIdentifiers, procedures of export and import catalog items in DIB nodes.
//              For partial embedding of the separate library function in the configuration without registration for support.
//
Function GeneralBasicFunctionalityParameters() Export
	
	CommonParameters = New Structure;
	CommonParameters.Insert("FormNamePersonalSettings", "");
	CommonParameters.Insert("MinimallyRequiredPlatformVersion", "8.3.4.365");
	CommonParameters.Insert("MustExit", False); // Lock the start if the version is less than min.
	CommonParameters.Insert("AskConfirmationOnExit", True);
	CommonParameters.Insert("DisableCatalogMetadataObjectIDs", False);
	
	CommonUseOverridable.OnDefiningGeneralParametersBasicFunctionality(CommonParameters);
	
	// For the backward compatibility.
	CommonUseOverridable.FormNamePersonalSettings(CommonParameters.FormNamePersonalSettings);
	CommonUseOverridable.GetMinRequiredPlatformVersion(CommonParameters);
	
	Return CommonParameters;
	
EndFunction

// Defines that this infobase is
// a subordinate node of the distributed infobase (DIB).
//
// Returns: 
//  Boolean
//
Function IsSubordinateDIBNode() Export
	
	SetPrivilegedMode(True);
	
	Return ExchangePlans.MasterNode() <> Undefined;
	
EndFunction

// Returns True if the configuration of DIB subordinate node infobase is required to be updated.
// In the main node always - False.
//
// Returns: 
//  Boolean
//
Function ConfigurationUpdateOfSlaveNodeWantedADB() Export
	
	Return IsSubordinateDIBNode() AND ConfigurationChanged();
	
EndFunction

// Returns True if the current session is executed on server managed by Linux OS.
//
// Returns:
//  Boolean - True if server is managed by Linux OS.
//
Function ThisLinuxServer() Export
	
	SystemInfo = New SystemInfo;
	Return SystemInfo.PlatformType = PlatformType.Linux_x86 OR SystemInfo.PlatformType = PlatformType.Linux_x86_64;
	
EndFunction

// Designed to insert the managed forms located on the desktop to
// the beginning of the OnCreateAtServer handler.
//
// Prevents form opening in some special cases.:
//  - if the desktop is opened before IB data
//   is updated (exclude possibility of knowingly erroneous call to the data that is not updated);
//  - if you log in the separated IB in the session
//  where
//  DataAreaBasicData separator value is not set (exclude possibility of knowingly erroneous call to the separated data from the undivided session);
//
// You should not use it in forms that are used
// before the system start and also in the forms intended for work in the undivided session.
//
// Parameters:
//  Form - ManagedForm - references to form that is being created.
//  Cancel - Boolean - parameter passed to handler of the OnCreateAtServer form.
//  StandardProcessing - Boolean - parameter passed to handler of the OnCreateAtServer form.
//
// Returns:
//  Boolean - If False, then the denial from form creation is set.
//
Function OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND Not CommonUseReUse.CanUseSeparatedData() Then
		Cancel = True;
		Return False;
	EndIf;
	
	If Form.Parameters.Property("AutoTest") Then
		// Return if the form for analysis is received.
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	If SessionParameters.ClientParametersOnServer.Get("HideDesktopOnStart") <> Undefined Then
		Cancel = True;
		Return False;
	EndIf;
	SetPrivilegedMode(False);
	
	Return True;
	
EndFunction

// Executes actions before continuing to execute scheduled job handler.
//
// For example, checks if it is possibile to execute the handler of scheduled job.
// If administrator does not lock the
// scheduled jobs before IB update is complete, then it is required to stop executing the handler.
// 
Procedure OnStartExecutingScheduledJob() Export
	
	If StandardSubsystemsServer.ShouldUpdateApplicationWorkParameters() Then
		Raise
			NStr("en='Entrance to the application is temporarily impossible due to the update to the new version.
					|It is recommended to prohibit the execution of the scheduled jobs during the update.';
				 |ru='Вход в программу временно невозможен в связи с обновлением на новую версию.
					|Рекомендуется запрещать выполнение регламентных заданий на время обновления.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not CommonUseReUse.DataSeparationEnabled()
	   AND ExchangePlans.MasterNode() = Undefined
	   AND ValueIsFilled(Constants.MasterNode.Get()) Then
		
		Raise
			NStr("en='Sign in to the application is temporarily unavailable before the restoration of connection with the main node.
					|It is recommended to prohibit the execution of the scheduled jobs on time of restoration.';
				 |ru='Вход в программу временно невозможен до восстановления связи с главным узлом.
					|Рекомендуется запрещать выполнение регламентных заданий на время восстановления.'");
	EndIf;
	
EndProcedure

// Returns the configuration edition.
// Edition two first digits groups of configuration full version.
// For example, version 1.2.3.4 edition 1.2".
//
// Returns:
//  String - configuration edition number.
//
Function ConfigurationEdition() Export
	
	Result = "";
	ConfigurationVersion = Metadata.Version;
	
	Position = Find(ConfigurationVersion, ".");
	If Position > 0 Then
		Result = Left(ConfigurationVersion, Position);
		ConfigurationVersion = Mid(ConfigurationVersion, Position + 1);
		Position = Find(ConfigurationVersion, ".");
		If Position > 0 Then
			Result = Result + Left(ConfigurationVersion, Position - 1);
		Else
			Result = "";
		EndIf;
	EndIf;
	
	If IsBlankString(Result) Then
		Result = Metadata.Version;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a row presentation of interval between
// the passed dates or relatively passed date and the current session date.
//
// Parameters:
//  BeginTime    - Date - initial point of interval.
//  EndTime - Date - interval end point if it is not specified. - the current session date is taken.
//
Function TimeIntervalAsString(BeginTime, EndTime = Undefined) Export
	
	If EndTime = Undefined Then
		EndTime = CurrentSessionDate();
	ElsIf BeginTime > EndTime Then
		Raise NStr("en='The interval end date cannot be earlier than the start date.';ru='Дата окончания интервала не может быть меньше даты начала.'");
	EndIf;
	
	IntervalSize = EndTime - BeginTime;
	IntervalSizeInDays = Int(IntervalSize/60/60/24);
	
	If IntervalSizeInDays > 365 Then
		DetailsOfInterval = NStr("en='more than a year';ru='более года'");
	ElsIf IntervalSizeInDays > 31 Then
		DetailsOfInterval = NStr("en='more than a month';ru='более месяца'");
	ElsIf IntervalSizeInDays >= 1 Then
		NumberInWords = NumberInWords(
			IntervalSizeInDays,
			"L=en_US",
			NStr("en=',,,,,,,,0';ru=',,,,,,,,0'"));
		SubjectAndNumberInWords = NumberInWords(
			IntervalSizeInDays,
			"L=en_US",
			NStr("en='day, day, days,,,,,,0';ru='день, дня, дней,,,,,,0'"));
		
		DetailsOfInterval = StrReplace(
			SubjectAndNumberInWords,
			NumberInWords,
			Format(IntervalSizeInDays, "NFD=0") + " ");
	Else
		DetailsOfInterval = NStr("en='less than a day';ru='менее одного дня'");
	EndIf;
	
	Return DetailsOfInterval;
	
EndFunction

// Function declines the passed phrase.
// Only for work on Windows OS.
//
// Parameters:
//  Initials   - String - surname, name and patronymic in
// nominative case that are required to be declined.
//  Case - Number  - case required for the full name.:
//                   1 - Nominative
//                   2 - Genitive
//                   3 - Dative
//                   4 - Accusative
//                   5 - Ablative
//                   case 6 - Offered
//  Result - String - the declination result is placed to this parameter .
//                       If the full name can not be declined, then the full name value is returned.
//  Gender       - Number - individual gender, 1 - male, 2 - female.
//
// Returns:
//   Boolean - True if it failed to decline the full name.
//
Function Decline(Val Initials, Case, Result, Gender = Undefined) Export
	
	AttachAddIn("CommonTemplate.DeclinationComponentDescriptionFull", "Decl");
	Component = New("AddIn.Decl.CNameDecl");
	
	Result = "";
	
	RowArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Initials, " ");
	
	// Select first 3 words as a component can not decline the phrase containing more than three characters.
	NumberIndeclinableSymbol = 4;
	For Number = 1 To min(RowArray.Count(), 3) Do
		If Not IndividualsClientServer.DescriptionFullIsTrue(RowArray[Number-1], True) Then
			NumberIndeclinableSymbol = Number;
			Break;
		EndIf;

		Result = Result + ?(Number > 1, " ", "") + RowArray[Number-1];
	EndDo;
	
	If IsBlankString(Result) Then
		Result = Initials;
		Return False;
	EndIf;
	
	Try
		If Gender = Undefined Then
			Result = Component.Decline(Result, Case) + " ";
			
		Else
			Result = Component.Decline(Result, Case, Gender) + " ";
			
		EndIf;
		
	Except
		Result = Initials;
		Return False;
		
	EndTry;
	
	// Add other characters without declination.
	For Number = NumberIndeclinableSymbol To RowArray.Count() Do
		Result = Result + " " + RowArray[Number-1];
	EndDo;
	
	Result = TrimAll(Result);
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with forms.

// Procedure is intended to fill in the form attribute of the FormDataTree type.
//
// Parameters:
//  TreeItemCollection - FormDataTree - attribute that needs to be filled in.
//  ValueTree           - ValueTree    - data for filling.
// 
Procedure FillItemCollectionOfFormDataTree(TreeItemCollection, ValueTree) Export
	
	For Each String In ValueTree.Rows Do
		
		TreeItem = TreeItemCollection.Add();
		
		FillPropertyValues(TreeItem, String);
		
		If String.Rows.Count() > 0 Then
			
			FillItemCollectionOfFormDataTree(TreeItem.GetItems(), String);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Receives picture for the output on page with
// comment depending if there is a text in the comment.
//
// Parameters:
//  Comment  - String - comment text.
//
// Returns:
//  Picture - Picture that should appear on a page with a comment.
//
Function GetCommentPicture(Comment) Export

	If Not IsBlankString(Comment) Then
		Picture = PictureLib.Comment;
	Else
		Picture = New Picture;
	EndIf;
	
	Return Picture;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for work with types, metadata objects and their row presentations.

// Receives the configuration metadata tree with the specified filter by the metadata objects.
// 
// Parameters:
//   Filter - Structure - contains values of the filter items.
// 					If parameter is specified, the metadata tree will be received according to the specified filter:
// 					Key - String - name of metadata item property;
// 					Value - Array - multiple values for filter.
// 
// Example of the Filter variable initialization:
// 
// Array = New Array;
// Array.Add(Constant.UseDataSynchronization);
// Array.Add(Catalog.Currencies);
// Array.Add(Catalog.Companies);
// Filter = New Structure;
// Filter.Insert(FullName, Array);
// 
//  Returns:
//   ValueTree - tree of configuration metadata description.
//
Function GetConfigurationMetadataTree(Filter = Undefined) Export
	
	UseFilter = (Filter <> Undefined);
	
	CollectionsOfMetadataObjects = New ValueTable;
	CollectionsOfMetadataObjects.Columns.Add("Name");
	CollectionsOfMetadataObjects.Columns.Add("Synonym");
	CollectionsOfMetadataObjects.Columns.Add("Picture");
	CollectionsOfMetadataObjects.Columns.Add("ObjectPicture");
	
	NewMetadataObjectCollectionRow("Constants",               NStr("en='Constants';ru='Константы'"),                 PictureLib.Constant,              PictureLib.Constant,                    CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("Catalogs",             NStr("en='Catalogs';ru='Справочники'"),               PictureLib.Catalog,             PictureLib.Catalog,                   CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("Documents",               NStr("en='Documents';ru='Документы'"),                 PictureLib.Document,               PictureLib.DocumentObject,               CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("ChartsOfCharacteristicTypes", NStr("en='Charts of characteristic types';ru='Планы видов характеристик'"), PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("ChartsOfAccounts",             NStr("en='Charts of accounts';ru='Планы счетов'"),              PictureLib.ChartOfAccounts,             PictureLib.ChartOfAccountsObject,             CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("ChartsOfCalculationTypes",       NStr("en='Charts of characteristic types';ru='Планы видов характеристик'"), PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("InformationRegisters",        NStr("en='Information registers';ru='Регистры сведений'"),         PictureLib.InformationRegister,        PictureLib.InformationRegister,              CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("AccumulationRegisters",      NStr("en='Accumulation registers';ru='Регистры накопления'"),       PictureLib.AccumulationRegister,      PictureLib.AccumulationRegister,            CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("AccountingRegisters",     NStr("en='Accounting registers';ru='Регистры бухгалтерии'"),      PictureLib.AccountingRegister,     PictureLib.AccountingRegister,           CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("CalculationRegisters",         NStr("en='Calculation registers';ru='Регистры расчета'"),          PictureLib.CalculationRegister,         PictureLib.CalculationRegister,               CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("BusinessProcesses",          NStr("en='Business processes';ru='Деловые процессы'"),           PictureLib.BusinessProcess,          PictureLib.BusinessProcessObject,          CollectionsOfMetadataObjects);
	NewMetadataObjectCollectionRow("Tasks",                  NStr("en='Tasks';ru='Задания'"),                    PictureLib.Task,                 PictureLib.TaskObject,                 CollectionsOfMetadataObjects);
	
	// Return value of the function.
	MetadataTree = New ValueTree;
	MetadataTree.Columns.Add("Name");
	MetadataTree.Columns.Add("FullName");
	MetadataTree.Columns.Add("Synonym");
	MetadataTree.Columns.Add("Picture");
	
	For Each CollectionRow In CollectionsOfMetadataObjects Do
		
		TreeRow = MetadataTree.Rows.Add();
		FillPropertyValues(TreeRow, CollectionRow);
		For Each MetadataObject In Metadata[CollectionRow.Name] Do
			
			If UseFilter Then
				
				ObjectPassedFilter = True;
				For Each FilterItem In Filter Do
					
					Value = ?(Upper(FilterItem.Key) = Upper("FullName"), MetadataObject.FullName(), MetadataObject[FilterItem.Key]);
					If FilterItem.Value.Find(Value) = Undefined Then
						ObjectPassedFilter = False;
						Break;
					EndIf;
					
				EndDo;
				
				If Not ObjectPassedFilter Then
					Continue;
				EndIf;
				
			EndIf;
			
			MOTreeRow = TreeRow.Rows.Add();
			MOTreeRow.Name       = MetadataObject.Name;
			MOTreeRow.FullName = MetadataObject.FullName();
			MOTreeRow.Synonym   = MetadataObject.Synonym;
			MOTreeRow.Picture  = CollectionRow.ObjectPicture;
			
		EndDo;
		
	EndDo;
	
	// Delete rows without subordinate items.
	If UseFilter Then
		
		// Use the reverse order of the tree values bypass.
		CollectionItemsQuantity = MetadataTree.Rows.Count();
		
		For ReverseIndex = 1 To CollectionItemsQuantity Do
			
			CurrentIndex = CollectionItemsQuantity - ReverseIndex;
			TreeRow = MetadataTree.Rows[CurrentIndex];
			If TreeRow.Rows.Count() = 0 Then
				MetadataTree.Rows.Delete(CurrentIndex);
			EndIf;
			
		EndDo;
	
	EndIf;
	
	Return MetadataTree;
	
EndFunction

// Receive presentation of actual infobase location for display to the administrator.
//
// Returns:
//   String - infobase presentation.
//
// Example of the return result:
// - for IB in the file mode: \\FileServer\1c_ib\
// - for IB in the server mode: ServerName:1111 / information_base_name.
//
Function GetInfobasePresentation() Export
	
	StringOfConnectionWithDB = InfobaseConnectionString();
	
	If FileInfobase(StringOfConnectionWithDB) Then
		Return Mid(StringOfConnectionWithDB, 6, StrLen(StringOfConnectionWithDB) - 6);
	EndIf;
		
	// Add name of the infobase path to the server name.
	SearchPosition = Find(Upper(StringOfConnectionWithDB), "SRVR=");
	If SearchPosition <> 1 Then
		Return Undefined;
	EndIf;
	
	SemicolonPosition = Find(StringOfConnectionWithDB, ";");
	CopyStartPosition = 6 + 1;
	CopyingEndPosition = SemicolonPosition - 2; 
	
	ServerName = Mid(StringOfConnectionWithDB, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
	
	StringOfConnectionWithDB = Mid(StringOfConnectionWithDB, SemicolonPosition + 1);
	
	// Position of the server name
	SearchPosition = Find(Upper(StringOfConnectionWithDB), "REF=");
	If SearchPosition <> 1 Then
		Return Undefined;
	EndIf;
	
	CopyStartPosition = 6;
	SemicolonPosition = Find(StringOfConnectionWithDB, ";");
	CopyingEndPosition = SemicolonPosition - 2; 
	
	InfobaseNameAtServer = Mid(StringOfConnectionWithDB, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
	PathToDB = ServerName + "/ " + InfobaseNameAtServer;
	Return PathToDB;
	
EndFunction

// Returns row of metadata objects attributes with the specified type.
// 
// Parameters:
//  Ref - AnyRef - ref to the infobase item for which it is required to receive the function result;
//  Type    - Type - attribute value type.
// 
// Returns:
//  String - attributes row of the configuration metadata object separated by , character.
//
Function NamesOfAttributesByType(Ref, Type) Export
	
	Result = "";
	ObjectMetadata = Ref.Metadata();
	
	For Each Attribute In ObjectMetadata.Attributes Do
		If Attribute.Type.ContainsType(Type) Then
			Result = Result + ?(IsBlankString(Result), "", ", ") + Attribute.Name;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Returns the name of basic type based on the transferred value of metadata object.
// 
// Parameters:
//  MetadataObject - metadata object for which it is necessary to define the base type.
// 
// Returns:
//  String - name of basic type based on the transferred value of metadata object.
//
Function BaseTypeNameByMetadataObject(MetadataObject) Export
	
	If Metadata.Documents.Contains(MetadataObject) Then
		Return TypeNameDocuments();
		
	ElsIf Metadata.Catalogs.Contains(MetadataObject) Then
		Return TypeNameCatalogs();
		
	ElsIf Metadata.Enums.Contains(MetadataObject) Then
		Return TypeNameEnums();
		
	ElsIf Metadata.InformationRegisters.Contains(MetadataObject) Then
		Return TypeNameInformationRegisters();
		
	ElsIf Metadata.AccumulationRegisters.Contains(MetadataObject) Then
		Return TypeNameAccumulationRegisters();
		
	ElsIf Metadata.AccountingRegisters.Contains(MetadataObject) Then
		Return TypeNameOfAccountingRegisters();
		
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObject) Then
		Return NameKindCalculationRegisters();
		
	ElsIf Metadata.ExchangePlans.Contains(MetadataObject) Then
		Return TypeNameExchangePlans();
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		Return TypeNameChartsOfCharacteristicTypes();
		
	ElsIf Metadata.BusinessProcesses.Contains(MetadataObject) Then
		Return BusinessProcessTypeName();
		
	ElsIf Metadata.Tasks.Contains(MetadataObject) Then
		Return TypeNameTasks();
		
	ElsIf Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
		Return TypeNameChartsOfAccounts();
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(MetadataObject) Then
		Return TypeNameChartsOfCalculationTypes();
		
	ElsIf Metadata.Constants.Contains(MetadataObject) Then
		Return TypeNameConstants();
		
	ElsIf Metadata.DocumentJournals.Contains(MetadataObject) Then
		Return TypeNameDocumentJournals();
		
	ElsIf Metadata.Sequences.Contains(MetadataObject) Then
		Return TypeNameSequences();
		
	ElsIf Metadata.ScheduledJobs.Contains(MetadataObject) Then
		Return TypeNameScheduledJobs();
		
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObject.Parent())
		AND MetadataObject.Parent().Recalculations.Find(MetadataObject.Name) = MetadataObject Then
		Return TypeNameRecalculations();
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

// Returns the object manager by a full metadata object name.
// Limitation: route points of business processes are not processed.
//
// Parameters:
//  FullName - String - Full metadata object name. Example: Catalog.Companies".
//
// Returns:
//  CatalogManager, DocumentManager.
// 
Function ObjectManagerByFullName(FullName) Export
	Var MOClass, MOName, Manager;
	
	NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullName, ".");
	
	If NameParts.Count() >= 2 Then
		MOClass = NameParts[0];
		MOName  = NameParts[1];
	EndIf;
	
	If      Upper(MOClass) = "EXCHANGEPLAN" Then
		Manager = ExchangePlans;
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Manager = Catalogs;
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Manager = Documents;
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Manager = DocumentJournals;
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Manager = Enums;
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Manager = Reports;
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Manager = DataProcessors;
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Manager = InformationRegisters;
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Manager = AccumulationRegisters;
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Manager = AccountingRegisters;
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		If NameParts.Count() = 2 Then
			// Calculation register
			Manager = CalculationRegisters;
		Else
			ClassSubordinateOM = NameParts[2];
			NameOfSlave = NameParts[3];
			If Upper(ClassSubordinateOM) = "RECALCULATION" Then
				// Recalculation
				Try
					Manager = CalculationRegisters[MOName].Recalculations;
					OmName = NameOfSlave;
				Except
					Manager = Undefined;
				EndTry;
			EndIf;
		EndIf;
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Manager = BusinessProcesses;
		
	ElsIf Upper(MOClass) = "TASK" Then
		Manager = Tasks;
		
	ElsIf Upper(MOClass) = "CONSTANT" Then
		Manager = Constants;
		
	ElsIf Upper(MOClass) = "SEQUENCE" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		Try
			Return Manager[MOName];
		Except
			Manager = Undefined;
		EndTry;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Unknown metadata object type %1';ru='Неизвестный тип объекта метаданных %1'"), FullName);
	
EndFunction

// Returns object manager by the reference to object.
// Limitation: route points of business processes are not processed.
//
// Parameters:
//  Ref - AnyRef - object, manager of which it is required to receive.
//
// Returns:
//  CatalogManager, DocumentManager.
// 
Function ObjectManagerByRef(Ref) Export
	
	ObjectName = Ref.Metadata().Name;
	ReferenceType = TypeOf(Ref);
	
	If Catalogs.AllRefsType().ContainsType(ReferenceType) Then
		Return Catalogs[ObjectName];
		
	ElsIf Documents.AllRefsType().ContainsType(ReferenceType) Then
		Return Documents[ObjectName];
		
	ElsIf BusinessProcesses.AllRefsType().ContainsType(ReferenceType) Then
		Return BusinessProcesses[ObjectName];
		
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(ReferenceType) Then
		Return ChartsOfCharacteristicTypes[ObjectName];
		
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(ReferenceType) Then
		Return ChartsOfAccounts[ObjectName];
		
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(ReferenceType) Then
		Return ChartsOfCalculationTypes[ObjectName];
		
	ElsIf Tasks.AllRefsType().ContainsType(ReferenceType) Then
		Return Tasks[ObjectName];
		
	ElsIf ExchangePlans.AllRefsType().ContainsType(ReferenceType) Then
		Return ExchangePlans[ObjectName];
		
	ElsIf Enums.AllRefsType().ContainsType(ReferenceType) Then
		Return Enums[ObjectName];
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Creates and returns an instance of the object by the full name of the metadata object.
// Limit: only reports and processors are supported.
//
// Parameters:
//   FullName - String - Full metadata object name. Example: Report.BusinessProcesses.
//
// Returns:
//   ReportObject, DataProcessorObject.
// 
Function ObjectByDescriptionFull(FullName) Export
	RowArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullName, ".");
	
	If RowArray.Count() >= 2 Then
		Kind = Upper(RowArray[0]);
		Name = RowArray[1];
	Else
		Raise StrReplace(NStr("en='Incorrect full name of the report or data processor %1.';ru='Некорректное полное имя отчета или обработки %1.'"), "%1", FullName);
	EndIf;
	
	If Kind = "REPORT" Then
		Return Reports[Name].Create();
	ElsIf Kind = "DATAPROCESSOR" Then
		Return DataProcessors[Name].Create();
	ElsIf Kind = "ExternalReport" Then
		Return ExternalReports.Create(Name);
	ElsIf Kind = "EXTERNALPROCESSOR" Then
		Return ExternalDataProcessors.Create(Name);
	Else
		Raise StrReplace(NStr("en='%1 is not a report or a data processor.';ru='%1 не является отчетом или обработкой.'"), "%1", FullName);
	EndIf;
EndFunction

// Checks if the record about the passed reference value is actually in the data infobase.
// 
// Parameters:
//  AnyRef - value of any data infobase reference.
// 
// Returns:
//  Boolean.
//
Function RefExists(AnyRef) Export
	
	QueryText = "
	|SELECT
	|	Ref AS Ref
	|FROM
	|	[TableName]
	|WHERE
	|	Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[TableName]", TableNameByRef(AnyRef));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", AnyRef);
	
	SetPrivilegedMode(True);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns the name of the metadata objects type by reference to object.
// Limitation: route points of business processes are not processed.
//
// Parameters:
//  Ref - AnyRef - object kind of which should be received.
//
// Returns:
//  String - name of the metadata objects kind. For example: Catalog, Document.
// 
Function ObjectKindByRef(Ref) Export
	
	Return ObjectKindByKind(TypeOf(Ref));
	
EndFunction 

// Returns the name of metadata objects kind by the object type.
// Limitation: route points of business processes are not processed.
//
// Parameters:
//  Type - Type - Type of the applied object defined in the configuration.
//
// Returns:
//  String - name of the metadata objects kind. For example: Catalog, Document.
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
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Incorrect type of parameter value (%1)';ru='Неверный тип значения параметра (%1)'"), String(Type));
	
	EndIf;
	
EndFunction 

// Returns full name of metadata object by the passed reference value.
// Examples:
//  Catalog.ProductsAndServices;
//  Document.SupplierInvoice.
// 
// Parameters:
//  Ref - AnyRef - object for which it is required to receive IB table name.
// 
// Returns:
//  String - full name of the metadata object for the specified object.
//
Function TableNameByRef(Ref) Export
	
	Return Ref.Metadata().FullName();
	
EndFunction

// Verify that the value has a reference data type.
//
// Parameters:
//  Value - Arbitrary - checked value.
//
// Returns:
//  Boolean - True if value type is reference.
//
Function ReferenceTypeValue(Value) Export
	
	Return IsReference(TypeOf(Value));
	
EndFunction

// Check if the passed type is a reference data type.
// False is returned for the Undefined type.
//
// Returns:
//  Boolean.
//
Function IsReference(Type) Export
	
	Return Type <> Type("Undefined") 
		AND (Catalogs.AllRefsType().ContainsType(Type)
		OR Documents.AllRefsType().ContainsType(Type)
		OR Enums.AllRefsType().ContainsType(Type)
		OR ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		OR ChartsOfAccounts.AllRefsType().ContainsType(Type)
		OR ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		OR BusinessProcesses.AllRefsType().ContainsType(Type)
		OR BusinessProcesses.RoutePointsAllRefsType().ContainsType(Type)
		OR Tasks.AllRefsType().ContainsType(Type)
		OR ExchangePlans.AllRefsType().ContainsType(Type));
	
EndFunction

// Checks if the object is a group of items.
//
// Parameters:
//  Object - AnyRef, Object - checked object.
//
// Returns:
//  Boolean.
//
Function ObjectIsFolder(Object) Export
	
	If ReferenceTypeValue(Object) Then
		Ref = Object;
	Else
		Ref = Object.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	
	If ThisIsCatalog(ObjectMetadata) Then
		
		If Not ObjectMetadata.Hierarchical
		 OR ObjectMetadata.HierarchyType
		     <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			
			Return False;
		EndIf;
		
	ElsIf Not ThisIsChartOfCharacteristicTypes(ObjectMetadata) Then
		Return False;
		
	ElsIf Not ObjectMetadata.Hierarchical Then
		Return False;
	EndIf;
	
	If Ref <> Object Then
		Return Object.IsFolder;
	EndIf;
	
	Return ObjectAttributeValue(Ref, "IsFolder") = True;
	
EndFunction

// Returns a ref that corresponds
// to the metadata object to use in the data base.
//  ForExample:
//  Identifier = CommonUse.MetadataObjectID(ValType(Ref));
//  Identifier = CommonUse.MetadataObjectIdentifier(MetadataObject);
//  Identifier = CommonUse.MetadataObjectID(Catalog.Companies);
//
//  Supported metadata objects:
// - Subsystems (it is required to application renaming).
// - Roles       (it is required to application renaming).
// - ExchangePlans
// - Constants
// - Catalogs
// - Documents
// - DocumentJournals
// - Reports
// - DataProcessors
// - ChartsOfCharacteristicTypes
// - ChartsOfAccounts
// - ChartsOfCalculationTypes
// - InformationRegisters
// - AccumulationRegisters
// - AccountingRegisters
// - CalculationRegisters
// - BusinessProcesses
// - Tasks
// 
// For the details,
// see the MetadataObjectsCollectionsProperties function of the MetadataObjectIDs catalog module manager.
//
// Parameters:
//  MetadataObjectDesc - MetadataObject - configuration metadata object;
//                            - Type - type that can be successfully used in the Metadata.FindByType() function;
//                            - String - full name of the metadata object
//                              that can be successfully used in Metadata.FindByFullName() function.
// Returns:
//  CatalogRef.MetadataObjectIDs.
//
Function MetadataObjectID(MetadataObjectDesc) Export
	
	MetadataObjectDescriptionType = TypeOf(MetadataObjectDesc);
	If MetadataObjectDescriptionType = Type("Type") Then
		
		MetadataObject = Metadata.FindByType(MetadataObjectDesc);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectID().
		|
		|Metadata object is not found by the type: %1';
		|ru='Ошибка при выполнении функции ОбщегоНазначения.ИдентификаторОбъектаМетаданных().
		|
		|Объект метаданных не найден по типу: %1.'"),
				MetadataObjectDesc);
		Else
			FullMetadataObjectName = MetadataObject.FullName();
		EndIf;
		
	ElsIf MetadataObjectDescriptionType = Type("String") Then
		FullMetadataObjectName = MetadataObjectDesc;
	Else
		FullMetadataObjectName = MetadataObjectDesc.FullName();
	EndIf;
	
	Return StandardSubsystemsReUse.MetadataObjectID(FullMetadataObjectName);
	
EndFunction

// Returns the metadata object by the passed identifier.
//
// Parameters:
//  ID - CatalogRef.MetadataObjectIDs - metadata object identifier.
//
// Returns:
//  MetadataObject.
//
Function MetadataObjectByID(ID) Export
	
	StandardSubsystemsReUse.CatalogMetadataObjectsIDsCheckUse(True);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Ref", ID);
	Query.Text =
	"SELECT
	|	IDs.Ref AS Ref,
	|	IDs.MetadataObjectKey,
	|	IDs.FullName,
	|	IDs.DeletionMark
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.Ref = &Ref";
	
	Exporting = Query.Execute().Unload();
	
	If Exporting.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectByID().
		|
		|Identifier %1 is not found in the ""Metadata objects identifiers catalog"".';
		|ru='Ошибка при выполнении функции ОбщегоНазначения.ОбъектМетаданныхПоИдентификатору()
		|
		|Идентификатор %1 не найден в справочнике ""Идентификаторы объектов метаданных"".'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
			String(ID));
	EndIf;
	
	// Check the match of metadata object key to the metadata object full name.
	CheckResult = Catalogs.MetadataObjectIDs.MetadataObjectKeyCorrespondsDescriptionFull(Exporting[0]);
	If CheckResult.NotCorresponds Then
		If CheckResult.MetadataObject = Undefined Then
			If CheckResult.MetadataObjectKey = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectByID().
		|
		|Nonexistent metadata object %2 corresponds to identifier %1 in the ""Metadata objects identifiers catalog"".';
		|ru='Ошибка при выполнении функции ОбщегоНазначения.ОбъектМетаданныхПоИдентификатору()
		|
		|Идентификатору %1 найденому в справочнике ""Идентификаторы объектов метаданных"", соответствует несуществующий объект метаданных %2.'")
					+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
					String(ID),
					Exporting[0].FullName);
			Else
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectByID().
		|
		|%1 identifier found in the Metadata objects identifiers catalog corresponds to the removed metadata object.';
		|ru='Ошибка при выполнении функции ОбщегоНазначения.ОбъектМетаданныхПоИдентификатору()
		|
		|Идентификатору %1 найденому в справочнике ""Идентификаторы объектов метаданных"", соответствует удаленный объект метаданных.'")
					+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
					String(ID));
			EndIf;
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectID().
		|
		|Identifier %1 found in the Metadata objects identifiers catalog corresponds
		|to the %2 metadata object. Its full name differs from the one specified in the identifier.';
		|ru='Ошибка при выполнении функции ОбщегоНазначения.ИдентификаторОбъектаМетаданных().
		|
		|Идентификатору %1 найденому в справочнике ""Идентификаторы объектов метаданных"",
		|соответствует объект метаданных %2, полное имя которого отличается от заданного в идентификаторе.'")
				+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
				String(ID),
				CheckResult.MetadataObject.FullName());
		EndIf;
	EndIf;
	
	If Exporting[0].DeletionMark Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectByID().
		|
		|%1 identifier is found in the ""Metadata objects identifier catalog"", but the ""Deletion markup"" attribute value is not set to True.';
		|ru='Ошибка при выполнении функции ОбщегоНазначения.ОбъектМетаданныхПоИдентификатору()
		|
		|Идентификатор %1 найден в справочнике ""Идентификаторы объектов метаданных"", но значение реквизита ""Пометка удаления"" установлено Истина.'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
			String(ID));
	EndIf;
	
	Return CheckResult.MetadataObject;
	
EndFunction

// To use in the
// OnAddMetadataObjectsRenaming procedure of the CommonUseOverridable common module for the description of objects metadata renaming.
// 
// Parameters:
//   Total                    - Structure - passed to the procedure by the BasicFunctionality subsystem.
//   IBVersion                - String    - version during the transition to which it is required to execute renaming.
//   FormerFullName         - String    - old full name of metadata object which needs to be renamed.
//   NewFullName          - String    - new  name of the metadata object to which it should be renamed.
//   LibraryID - String    - internal library identifier to which IBVersion relates.
//                                         It is not required for the main configuration.
// 
Procedure AddRenaming(Total, IBVersion, FormerFullName, NewFullName, LibraryID = "") Export
	
	StandardSubsystemsReUse.CatalogMetadataObjectsIDsCheckUse();
	
	FormerCollectionName = Upper(CollectionName(FormerFullName));
	NewCollectionName  = Upper(CollectionName(NewFullName));
	
	ErrorTitle =
		NStr("en='An error occurred in the OnAddMetadataObjectsRenaming procedure of the CommonUseOverridable common module.';ru='Ошибка в процедуре ПриДобавленииПереименованийОбъектовМетаданных общего модуля ОбщегоНазначенияПереопределяемый.'");
	
	If FormerCollectionName <> NewCollectionName Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			ErrorTitle + Chars.LF + Chars.LF
			+ NStr("en='Types names of the renamed metadata object do not match. Previous type: %1, new type: %2.';
				   |ru='Не совпадают имена типов переименованного объекта метаданных. Прежний тип: %1, новый тип: %2.'"),
			FormerFullName,
			NewFullName);
	EndIf;
	
	If Total.CollectionWithoutKey[FormerCollectionName] = Undefined Then
		
		ValidTypesList = "";
		For Each KeyAndValue In Total.CollectionWithoutKey Do
			ValidTypesList = ValidTypesList + KeyAndValue.Value + "," + Chars.LF;
		EndDo;
		ValidTypesList = TrimR(ValidTypesList);
		ValidTypesList = ?(ValueIsFilled(ValidTypesList),
			Left(ValidTypesList, StrLen(ValidTypesList) - 1), "");
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			ErrorTitle + Chars.LF + Chars.LF
			+ NStr("en='It is not required to describe renaming for
		|metadata object type %1 as information about metadata object of this type is updated automatically.
		|
		|It is required to describe renamings only for the following types: %2.';
		|ru='Для типа объекта метаданных %1 не
		|требуется описывать переименование, так как сведения об объектах метаданных этого типа обновляются автоматически.
		|
		|Описывать переименования требуется только для следующих типов: %2.'"),
			FormerFullName,
			NewFullName,
			ValidTypesList);
	EndIf;
	
	If ValueIsFilled(LibraryID) Then
		Library = Upper(LibraryID) <> Upper(Metadata.Name);
	Else
		LibraryID = Metadata.Name;
		Library = False;
	EndIf;
	
	LibraryOrder = Total.LibrariesLevel[LibraryID];
	If LibraryOrder = Undefined Then
		LibraryOrder = Total.LibrariesLevel.Count();
		Total.LibrariesLevel.Insert(LibraryID, LibraryOrder);
	EndIf;
	
	LibraryVersion = Total.LibrariesVersion[LibraryID];
	If LibraryVersion = Undefined Then
		LibraryVersion = InfobaseUpdateService.IBVersion(LibraryID);
		Total.LibrariesVersion.Insert(LibraryID, LibraryVersion);
	EndIf;
	
	If LibraryVersion = "0.0.0.0" Then
		// During the initial filling of renaming is not required.
		Return;
	EndIf;
	
	Result = CommonUseClientServer.CompareVersions(IBVersion, LibraryVersion);
	If Result > 0 Then
		VersionParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(IBVersion, ".");
		
		RenamingDescription = Total.Table.Add();
		RenamingDescription.LibraryOrder = LibraryOrder;
		RenamingDescription.VersionPart1      = Number(VersionParts[0]);
		RenamingDescription.VersionPart2      = Number(VersionParts[1]);
		RenamingDescription.VersionPart3      = Number(VersionParts[2]);
		RenamingDescription.VersionPart4      = Number(VersionParts[3]);
		RenamingDescription.FormerFullName   = FormerFullName;
		RenamingDescription.NewFullName    = NewFullName;
		RenamingDescription.AddingOrder = Total.Table.IndexOf(RenamingDescription);
	EndIf;
	
EndProcedure

// Returns the string presentation of the type. 
// For reference types it returns in the format "CatalogRef.ObjectName" or "DocumentRef.ObjectName".
// For other types it converts type to a string, for example, Number.
//
// Returns:
//  Row.
//
Function TypePresentationString(Type) Export
	
	Presentation = "";
	
	If IsReference(Type) Then
	
		FullName = Metadata.FindByType(Type).FullName();
		ObjectName = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullName, ".")[1];
		
		If Catalogs.AllRefsType().ContainsType(Type) Then
			Presentation = "CatalogRef";
		
		ElsIf Documents.AllRefsType().ContainsType(Type) Then
			Presentation = "DocumentRef";
		
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			Presentation = "BusinessProcessRef";
		
		ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCharacteristicTypesRef";
		
		ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfAccountsRef";
		
		ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCalculationTypesRef";
		
		ElsIf Tasks.AllRefsType().ContainsType(Type) Then
			Presentation = "TaskRef";
		
		ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
			Presentation = "ExchangePlanRef";
		
		ElsIf Enums.AllRefsType().ContainsType(Type) Then
			Presentation = "EnumRef";
		
		EndIf;
		
		Result = ?(Presentation = "", Presentation, Presentation + "." + ObjectName);
		
	Else
		
		Result = String(Type);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Check that the type description consists of a single value type and  matches the required type.
//
// Parameters:
//   DescriptionOfType - TypeDescription - checked types collection;
//   ValueType  - Type - checked type.
//
// Returns:
//   Boolean      - True if it matches.
//
Function TypeDescriptionFullConsistsOfType(DescriptionOfType, ValueType) Export
	
	If DescriptionOfType.Types().Count() = 1
	   AND DescriptionOfType.Types().Get(0) = ValueType Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Checks if the catalog has tabular section.
//
// Parameters:
//  CatalogName    - String - name of the catalog for which the check is executed.
//  TabularSectionName - String - tabular section name the presence of which is checked.
//
// Returns:
//  Boolean - True if there is a tabular section.
//
// Example:
//  If NOT CommonUse.TabularSectionInCatalogPresence
//  	(CatalogName, ContactInfo) Then Return;
//  EndIf;
//
Function CatalogHasTabularSection(CatalogName, TabularSectionName) Export
	
	Return (Metadata.Catalogs[CatalogName].TabularSections.Find(TabularSectionName) <> Undefined);
	
EndFunction 

// Returns the flag showing that the attribute is included into the subset of standard attributes.
// 
// Parameters:
//  StandardAttributes - StandardAttributesDescription - type and value describes the
//                                                         collection of settings for various standard attributes;
//  AttributeName         - String - attribute to be checked for inclusion
//                                  into standard attribute set.;
// 
// Returns:
//   Boolean - True if the attribute is included in the subset of standard attributes.
//
Function ThisIsStandardAttribute(StandardAttributes, AttributeName) Export
	
	For Each Attribute In StandardAttributes Do
		If Attribute.Name = AttributeName Then
			Return True;
		EndIf;
	EndDo;
	Return False;
	
EndFunction

// Receives values table with the description of the required properties of all metadata object attributes.
// Receives properties values of the standard attributes and the user attributes (created in the configurator mode).
//
// Parameters:
//  MetadataObject  - MetadataObject - object for which it is required to receive values of attributes properties.
//                      For
//  example: Metadata.Document.GoodsAndServicesImplementation Properties - String - attributes properties separated by commas, and it is required to receive their values.
//                      For example: Name, Type, Synonym, ToolTip.
//
// Returns:
//  ValueTable - description of the required properties of all metadata object attributes.
//
Function GetTableOfDescriptionOfObjectProperties(MetadataObject, Properties) Export
	
	PropertyArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Properties);
	
	// Return value of the function.
	TableOfDescriptionOfObjectProperties = New ValueTable;
	
	// Add fields to table according to the names of the passed properties.
	For Each PropertyName In PropertyArray Do
		TableOfDescriptionOfObjectProperties.Columns.Add(TrimAll(PropertyName));
	EndDo;
	
	// Fill in the table row with attributes properties of metadata object.
	For Each Attribute In MetadataObject.Attributes Do
		FillPropertyValues(TableOfDescriptionOfObjectProperties.Add(), Attribute);
	EndDo;
	
	// Fill in the table row with the properties of metadata object standard attributes.
	For Each Attribute In MetadataObject.StandardAttributes Do
		FillPropertyValues(TableOfDescriptionOfObjectProperties.Add(), Attribute);
	EndDo;
	
	Return TableOfDescriptionOfObjectProperties;
	
EndFunction

// Returns the state of using content item of the common attribute.
//
// Parameters:
//  ContentItem            - MetadataObject - item of common content attribute use
//                                                 of which should be checked.
//  CommonAttributeMetadata - MetadataObject - metadata object of a common
//                                                 attribute to which ContentItem belongs.
//
// Returns:
//  Boolean - True if the content item is used, otherwise, False.
//
Function CommonAttributeContentItemUsed(Val ContentItem, Val CommonAttributeMetadata) Export
	
	If ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Use Then
		Return True;
	ElsIf ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.DontUse Then
		Return False;
	Else
		Return CommonAttributeMetadata.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use;
	EndIf;
	
EndFunction

// Returns the flag showing that the metadata object is used in the common attributes-separators.
//
// Parameters:
//  MetadataObject - String, MetadataObject - If the metadata object is specified by a
//                     row, accessing re-use module is executed.
//  Delimiter      - String - name of the common attribute-separator and the metadata object is checked whether it was separated by it.
//
// Returns:
//  Boolean - True if metadata object is used at least in one common separator.
//
Function IsSeparatedMetadataObject(Val MetadataObject, Val Delimiter) Export
	
	If TypeOf(MetadataObject) = Type("String") Then
		FullMetadataObjectName = MetadataObject;
	Else
		FullMetadataObjectName = MetadataObject.FullName();
	EndIf;
	
	SeparatedMetadataObjects = CommonUseReUse.SeparatedMetadataObjects(Delimiter);
	Return SeparatedMetadataObjects.Get(FullMetadataObjectName) <> Undefined;
	
EndFunction

// Returns the predefined item name by the specified reference.
// To use instead of the outdated
// GetPredefinedItemName method in configurations designed for the platform of version 8.2.
//
// Parameters:
//  Ref - AnyRef - references to the predefined item.
//
// Returns:
//  String - name of the predefined item.
//
Function PredefinedName(Val Ref) Export
	
	Return ObjectAttributeValue(Ref, "PredefinedDataName");
	
EndFunction

// Object constructor TypeDescription that contains the Row type.
//
// Parameters:
//  StringLength - Number.
//
// ReturnValue:
//  TypeDescription.
Function TypeDescriptionRow(StringLength) Export

	Array = New Array;
	Array.Add(Type("String"));

	QualifierRows = New StringQualifiers(StringLength, AllowedLength.Variable);

	Return New TypeDescription(Array, , QualifierRows);

EndFunction

// Object constructor TypeDescription that contains the Number type.
//
// Parameters:
//  Digits - Number - total quantity of digit positions
//                        (quantity of digits positions of the integer part plus digits positions of the fractional part).
//  FractionDigits - Number - the number of fractional part digit positions
//  NumberSign - AllowedSign - valid number sign.
//
// ReturnValue:
//  TypeDescription.
Function TypeDescriptionNumber(Digits, FractionDigits = 0, NumberSign = Undefined) Export

	If NumberSign = Undefined Then
		QualifierOfNumber = New NumberQualifiers(Digits, FractionDigits);
	Else
		QualifierOfNumber = New NumberQualifiers(Digits, FractionDigits, NumberSign);
	EndIf;

	Return New TypeDescription("Number", QualifierOfNumber);

EndFunction

// Object constructor TypeDescription that contains the Date type.
//
// Parameters:
//  DateFractions - DateFractions - set of the values use variants of the Date type.
//
// ReturnValue:
//  TypeDescription.
Function TypeDescriptionDate(DateFractions) Export

	Array = New Array;
	Array.Add(Type("Date"));

	DateQualifier = New DateQualifiers(DateFractions);

	Return New TypeDescription(Array, , , DateQualifier);

EndFunction

// Allows to define whether there is an attribute with the passed name among the object attributes.
//
// Parameters:
//  AttributeName - String - attribute name;
//  ObjectMetadata - MetadataObject - object in which it is required to check the attribute presence.
//
// Returns:
//  Boolean.
//
Function IsObjectAttribute(AttributeName, ObjectMetadata) Export

	Return Not (ObjectMetadata.Attributes.Find(AttributeName) = Undefined);

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions of metadata objects types definition.

// Referential data types

// Defines if metadata object belongs to the Document common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsDocument(MetadataObject) Export
	
	Return Metadata.Documents.Contains(MetadataObject);
	
EndFunction

// Defines metadata object belonging to Catalog common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsCatalog(MetadataObject) Export
	
	Return Metadata.Catalogs.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Listed common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function IsEnum(MetadataObject) Export
	
	Return Metadata.Enums.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Exchange plan common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsExchangePlan(MetadataObject) Export
	
	Return Metadata.ExchangePlans.Contains(MetadataObject);
	
EndFunction

// Defines a metadata object belonging to Characteristic Kinds Plan common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsChartOfCharacteristicTypes(MetadataObject) Export
	
	Return Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Business process common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsBusinessProcess(MetadataObject) Export
	
	Return Metadata.BusinessProcesses.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Task common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsTask(MetadataObject) Export
	
	Return Metadata.Tasks.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Chart of accounts common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsChartOfAccounts(MetadataObject) Export
	
	Return Metadata.ChartsOfAccounts.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Chart of calculation types common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsChartOfCalculationTypes(MetadataObject) Export
	
	Return Metadata.ChartsOfCalculationTypes.Contains(MetadataObject);
	
EndFunction

// Registers

// Defines if metadata object belongs to the Information register common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsInformationRegister(MetadataObject) Export
	
	Return Metadata.InformationRegisters.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Accumulation register common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsAccumulationRegister(MetadataObject) Export
	
	Return Metadata.AccumulationRegisters.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Accounting register common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsAccountingRegister(MetadataObject) Export
	
	Return Metadata.AccountingRegisters.Contains(MetadataObject);
	
EndFunction

// Defines if metadata object belongs to the Calculation register common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsCalculationRegister(MetadataObject) Export
	
	Return Metadata.CalculationRegisters.Contains(MetadataObject);
	
EndFunction

// Constants

// Defines if metadata object belongs to the Constant common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsConstant(MetadataObject) Export
	
	Return Metadata.Constants.Contains(MetadataObject);
	
EndFunction

// Document journals

// Defines if metadata object belongs to the Documents log common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function IsDocumentJournal(MetadataObject) Export
	
	Return Metadata.DocumentJournals.Contains(MetadataObject);
	
EndFunction

// Sequences

// Defines if metadata object belongs to the Sequence common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisSequence(MetadataObject) Export
	
	Return Metadata.Sequences.Contains(MetadataObject);
	
EndFunction

// ScheduledJobs

// Defines if metadata object belongs to the Scheduled jobs common type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsScheduledJob(MetadataObject) Export
	
	Return Metadata.ScheduledJobs.Contains(MetadataObject);
	
EndFunction

// Common

// Defines if metadata object belongs to the register type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsRegister(MetadataObject) Export
	
	Return Metadata.AccountingRegisters.Contains(MetadataObject)
		Or Metadata.AccumulationRegisters.Contains(MetadataObject)
		Or Metadata.CalculationRegisters.Contains(MetadataObject)
		Or Metadata.InformationRegisters.Contains(MetadataObject);
		
EndFunction

// Defines if the metadata object belongs to the reference type.
// 
// Parameters:
//  MetadataObject - MetadataObject - object for which it is required to define whether it belongs to the specified type.
// 
//  Returns:
//   Boolean.
//
Function ThisIsObjectOfReferentialType(MetadataObject) Export
	
	MetadataObjectName = MetadataObject.FullName();
	Position = Find(MetadataObjectName, ".");
	If Position > 0 Then 
		BaseTypeName = Left(MetadataObjectName, Position - 1);
		Return BaseTypeName = "Catalog"
			Or BaseTypeName = "Document"
			Or BaseTypeName = "BusinessProcess"
			Or BaseTypeName = "Task"
			Or BaseTypeName = "ChartOfAccounts"
			Or BaseTypeName = "ExchangePlan"
			Or BaseTypeName = "ChartOfCharacteristicTypes"
			Or BaseTypeName = "ChartOfCalculationTypes";
	Else
		Return False;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Types names.

// Returns the value for Data Registers common type identification.
//
// Returns:
//  Row.
//
Function TypeNameInformationRegisters() Export
	
	Return "InformationRegisters";
	
EndFunction

// Returns the value for Accumulation Registers common type identification.
//
// Returns:
//  Row.
//
Function TypeNameAccumulationRegisters() Export
	
	Return "AccumulationRegisters";
	
EndFunction

// Returns the value for Accounting Registers common type identification.
//
// Returns:
//  Row.
//
Function TypeNameOfAccountingRegisters() Export
	
	Return "AccountingRegisters";
	
EndFunction

// Returns the value for Calculation Registers common type identification.
//
// Returns:
//  Row.
//
Function NameKindCalculationRegisters() Export
	
	Return "CalculationRegisters";
	
EndFunction

// Return a value to identify common type "Documents".
//
// Returns:
//  Row.
//
Function TypeNameDocuments() Export
	
	Return "Documents";
	
EndFunction

// Returns the value for Catalogs common type identification.
//
// Returns:
//  Row.
//
Function TypeNameCatalogs() Export
	
	Return "Catalogs";
	
EndFunction

// Returns the value for Transfers common type identification.
//
// Returns:
//  Row.
//
Function TypeNameEnums() Export
	
	Return "Enums";
	
EndFunction

// Returns the value for the Reports common type identification.
//
// Returns:
//  Row.
//
Function TypeNameReports() Export
	
	Return "Reports";
	
EndFunction

// Returns value for the Handlers common type identification.
//
// Returns:
//  Row.
//
Function TypeNameDataProcessors() Export
	
	Return "DataProcessors";
	
EndFunction

// Returns the value for ExchangePlans common type identification.
//
// Returns:
//  Row.
//
Function TypeNameExchangePlans() Export
	
	Return "ExchangePlans";
	
EndFunction

// Returns the value for Characteristics Kinds Plans common type identification.
//
// Returns:
//  Row.
//
Function TypeNameChartsOfCharacteristicTypes() Export
	
	Return "ChartsOfCharacteristicTypes";
	
EndFunction

// Returns the value for Business Processes common type identification.
//
// Returns:
//  Row.
//
Function BusinessProcessTypeName() Export
	
	Return "BusinessProcesses";
	
EndFunction

// Returns a value for the Tasks common type identification.
//
// Returns:
//  Row.
//
Function TypeNameTasks() Export
	
	Return "Tasks";
	
EndFunction

// Returns the value for Charts of Accounts common type identification.
//
// Returns:
//  Row.
//
Function TypeNameChartsOfAccounts() Export
	
	Return "ChartsOfAccounts";
	
EndFunction

// Returns the value for Calculation Kind Plans common type identification.
//
// Returns:
//  Row.
//
Function TypeNameChartsOfCalculationTypes() Export
	
	Return "ChartsOfCalculationTypes";
	
EndFunction

// Returns the value for Constants common type identification.
//
// Returns:
//  Row.
//
Function TypeNameConstants() Export
	
	Return "Constants";
	
EndFunction

// Returns the value for Document Journals common type identification.
//
// Returns:
//  Row.
//
Function TypeNameDocumentJournals() Export
	
	Return "DocumentJournals";
	
EndFunction

// Returns the value for Sequences common type identification.
//
// Returns:
//  Row.
//
Function TypeNameSequences() Export
	
	Return "Sequences";
	
EndFunction

// Returns a value for the ScheduledJobs common type identification.
//
// Returns:
//  Row.
//
Function TypeNameScheduledJobs() Export
	
	Return "ScheduledJobs";
	
EndFunction

// Returns the value for the Recalculations common type identification.
//
// Returns:
//  Row.
//
Function TypeNameRecalculations() Export
 
 Return "Recalculations";
 
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Saving, reading and deleting settings from storage.

// Saves the setting in common settings storage.
//
// Parameters:
//   ObjectKey       - String - Key of setting object.
//   SettingsKey      - String - Key of saved settings.
//   Value          - Arbitrary     - Settings that should be saved to the storage. 
//   SettingsDescription  - SettingsDescription - Helper information about setting.
//   UserName   - String - User’s name, their settings are saved.
//       If it is not specified, then settings of the current user are saved.
//   NeedToUpdateReusedValues - Boolean - Reset the caches of the ReUse modules.
//
// See also:
//   SettingsStandardStorageManager.Save in the syntax-assistant.
//
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey = "", Value,
	SettingsDescription = Undefined, UserName = Undefined, 
	NeedToUpdateReusedValues = False) Export
	
	StorageSave(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		Value,
		SettingsDescription,
		UserName,
		NeedToUpdateReusedValues);
	
EndProcedure

// Imports the setting from common settings storage.
//
// Parameters:
//   ObjectKey  - String - Key of setting object.
//   SettingsKey - String - Optional. Key of saved settings.
//   DefaultValue - Arbitrary - Optional.
//       Value that is required to be substituted if settings are not imported.
//   SettingsDescription - SettingsDescription - Optional. Helper info about setting is
//       written to this parameter while reading the settings value.
//   UserName - String - Optional. User’s name, their settings are being imported.
//       If it is not specified, then settings of the current user are imported.
//
// Returns: 
//   Arbitrary - Settings imported from storage.
//   Undefined - If settings are not found and the DefaultValue parameter is not specified.
//
// See also:
//   SettingsStandardStorageManager.Import in the syntax-assistant.
//
Function CommonSettingsStorageImport(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageImport(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
	
EndFunction

// Deletes the setting from the common settings storage.
//
// Parameters:
//   ObjectKey  - String       - Key of setting object. 
//                - Undefined - Settings for all objects are deleted.
//   SettingsKey - String       - Key of saved settings.
//                - Undefined - Settings with all keys are deleted.
//   UserName - String       - User’s name, their settings are imported.
//                   - Undefined - Settings of all users are deleted.
//
// See also:
//   SettingsStandardStorageManager.Delete in the syntax-assistant.
//
Procedure CommonSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName);
	
EndProcedure

// Saves an array of the StructuresArray custom settings. 
// Can be applied if there are calls from client.
// 
// Parameters:
//    StructuresArray - Array - array of structures with the Object, Setting, Value fields.
//    NeedToUpdateReusedValues - Boolean - it is required to update used values again.
//
Procedure CommonSettingsStorageSaveArray(StructuresArray,
	NeedToUpdateReusedValues = False) Export
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	For Each Item In StructuresArray Do
		CommonSettingsStorage.Save(Item.Object, SettingsKey(Item.Setting), Item.Value);
	EndDo;
	
	If NeedToUpdateReusedValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// Saves an array of the StructuresArray custom
//   settings and updates used values again. Can be applied if there are calls from client.
// 
// Parameters:
//    StructuresArray - Array - array of structures with the Object, Setting, Value fields.
//
Procedure CommonSettingsStorageSaveArrayAndUpdateReUseValues(StructuresArray) Export
	
	CommonSettingsStorageSaveArray(StructuresArray, True);
	
EndProcedure

// Saves a setting to the storage of the common settings
// and updates used values again.
// 
// Parameters:
//   Correspond to
// CommonSettingsStorageSave.Save method, for more details - see StorageSave procedure parameters().
//
Procedure CommonSettingsStorageSaveAndRefreshReusableValues(ObjectKey, SettingsKey, Value) Export
	
	CommonSettingsStorageSave(ObjectKey, SettingsKey, Value,,,True);
	
EndProcedure

// Saves the setting to storage of the system settings.
//
// Parameters:
//   ObjectKey       - String - Key of setting object.
//   SettingsKey      - String - Key of saved settings.
//   Value          - Arbitrary     - Settings that should be saved to the storage. 
//   SettingsDescription  - SettingsDescription - Helper information about setting.
//   UserName   - String - User’s name, their settings are saved.
//       If it is not specified, then settings of the current user are saved.
//   NeedToUpdateReusedValues - Boolean - Reset the caches of the ReUse modules.
//
// See also:
//   SettingsStandardStorageManager.Save in the syntax-assistant.
//
Procedure SystemSettingsStorageSave(ObjectKey, SettingsKey = "", Value,
	SettingsDescription = Undefined, UserName = Undefined, 
	NeedToUpdateReusedValues = False) Export
	
	StorageSave(
		SystemSettingsStorage, 
		ObjectKey, 
		SettingsKey, 
		Value,
		SettingsDescription, 
		UserName, 
		NeedToUpdateReusedValues);
	
EndProcedure

// Imports the setting from the storage of system settings.
//
// Parameters:
//   ObjectKey  - String - Key of setting object.
//   SettingsKey - String - Optional. Key of saved settings.
//   DefaultValue - Arbitrary - Optional.
//       Value that is required to be substituted if settings are not imported.
//   SettingsDescription - SettingsDescription - Optional. Helper info about setting is
//       written to this parameter while reading the settings value.
//   UserName - String - Optional. User’s name, their settings are being imported.
//       If it is not specified, then settings of the current user are imported.
//
// Returns: 
//   Arbitrary - Settings imported from storage.
//   Undefined - If settings are not found and the DefaultValue parameter is not specified.
//
// See also:
//   SettingsStandardStorageManager.Import in the syntax-assistant.
//
Function SystemSettingsStorageImport(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageImport(
		SystemSettingsStorage, 
		ObjectKey, 
		SettingsKey, 
		DefaultValue, 
		SettingsDescription, 
		UserName);
	
EndFunction

// Deletes the setting from the storage of the system settings.
//
// Parameters:
//   ObjectKey  - String       - Key of setting object. 
//                - Undefined - Settings for all objects are deleted.
//   SettingsKey - String       - Key of saved settings.
//                - Undefined - Settings with all keys are deleted.
//   UserName - String       - User’s name, their settings are imported.
//                   - Undefined - Settings of all users are deleted.
//
// See also:
//   SettingsStandardStorageManager.Delete in the syntax-assistant.
//
Procedure SystemSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(
		SystemSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName);
	
EndProcedure

// Saves the setting to storage of form data settings.
//
// Parameters:
//   ObjectKey       - String - Key of setting object.
//   SettingsKey      - String - Key of saved settings.
//   Value          - Arbitrary     - Settings that should be saved to the storage. 
//   SettingsDescription  - SettingsDescription - Helper information about setting.
//   UserName   - String - User’s name, their settings are saved.
//       If it is not specified, then settings of the current user are saved.
//   NeedToUpdateReusedValues - Boolean - Reset the caches of the ReUse modules.
//
// See also:
//   SettingsStandardStorageManager.Save in the syntax-assistant.
//
Procedure FormDataSettingsStorageSave(ObjectKey, SettingsKey = "", Value,
	SettingsDescription = Undefined, UserName = Undefined, 
	NeedToUpdateReusedValues = False) Export
	
	StorageSave(
		FormDataSettingsStorage, 
		ObjectKey, 
		SettingsKey, 
		Value,
		SettingsDescription, 
		UserName, 
		NeedToUpdateReusedValues);
	
EndProcedure

// Imports the setting from storage of form data settings.
//
// Parameters:
//   ObjectKey  - String - Key of setting object.
//   SettingsKey - String - Optional. Key of saved settings.
//   DefaultValue - Arbitrary - Optional.
//       Value that is required to be substituted if settings are not imported.
//   SettingsDescription - SettingsDescription - Optional. Helper info about setting is
//       written to this parameter while reading the settings value.
//   UserName - String - Optional. User’s name, their settings are being imported.
//       If it is not specified, then settings of the current user are imported.
//
// Returns: 
//   Arbitrary - Settings imported from storage.
//   Undefined - If settings are not found and the DefaultValue parameter is not specified.
//
// See also:
//   SettingsStandardStorageManager.Import in the syntax-assistant.
//
Function FormDataSettingsStorageImport(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return StorageImport(
		FormDataSettingsStorage, 
		ObjectKey, 
		SettingsKey, 
		DefaultValue, 
		SettingsDescription, 
		UserName);
	
EndFunction

// Deletes the setting from the storage of form data settings.
//
// Parameters:
//   ObjectKey  - String       - Key of setting object. 
//                - Undefined - Settings for all objects are deleted.
//   SettingsKey - String       - Key of saved settings.
//                - Undefined - Settings with all keys are deleted.
//   UserName - String       - User’s name, their settings are imported.
//                   - Undefined - Settings of all users are deleted.
//
// See also:
//   SettingsStandardStorageManager.Delete in the syntax-assistant.
//
Procedure FormDataSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	StorageDelete(
		FormDataSettingsStorage,
		ObjectKey,
		SettingsKey,
		UserName);
	
EndProcedure

// Saves the setting to settings storage via its manager.
//
// Parameters:
//   StorageManager - StandardSettingsStorageManager - Storage where the setting is saved.
//   ObjectKey       - String - Key of setting object.
//   SettingsKey      - String - Key of saved settings.
//   Value          - Arbitrary     - Settings that should be saved to the storage. 
//   SettingsDescription  - SettingsDescription - Helper information about setting.
//   UserName   - String - User’s name, their settings are saved.
//       If it is not specified, then settings of the current user are saved.
//   NeedToUpdateReusedValues - Boolean - Reset the caches of the ReUse modules.
//
// See also:
//   SettingsStandardStorageManager.Save in the syntax-assistant.
//   "Settings automatically saved in the system storage" in the syntax-assistant.
//
Procedure StorageSave(StorageManager, ObjectKey, SettingsKey, Value,
	SettingsDescription, UserName, NeedToUpdateReusedValues)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	StorageManager.Save(ObjectKey, SettingsKey(SettingsKey), Value, SettingsDescription, UserName);
	
	If NeedToUpdateReusedValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// Upoads setting from settings storage via its manager.
//
// Parameters:
//   StorageManager - StandardSettingsStorageManager - Storage from which the setting is imported.
//   ObjectKey  - String - Key of setting object.
//   SettingsKey - String - Optional. Key of saved settings.
//   DefaultValue - Arbitrary - Optional.
//       Value that is required to be substituted if settings are not imported.
//   SettingsDescription - SettingsDescription - Optional. Helper info about setting is
//       written to this parameter while reading the settings value.
//   UserName - String - Optional. User’s name, their settings are being imported.
//       If it is not specified, then settings of the current user are imported.
//
// Returns: 
//   Arbitrary - Settings imported from storage.
//   Undefined - If settings are not found and the DefaultValue parameter is not specified.
//
// See also:
//   SettingsStandardStorageManager.Import in the syntax-assistant.
//   "Settings automatically saved in the system storage" in the syntax-assistant.
//
Function StorageImport(StorageManager, ObjectKey, SettingsKey, DefaultValue,
	SettingsDescription, UserName)
	
	Result = Undefined;
	
	If AccessRight("SaveUserData", Metadata) Then
		Result = StorageManager.Load(ObjectKey, SettingsKey(SettingsKey), SettingsDescription, UserName);
	EndIf;
	
	If Result = Undefined Then
		Result = DefaultValue;
	Else
		SetPrivilegedMode(True);
		If DeleteBrokenRefs(Result) Then
			Result = DefaultValue;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// Deletes dead references from the variable.
//
// Parameters:
//   RefOrCollection - AnyRef, Custom - Checked object or cleared collection.
//
// Returns: 
//   Boolean - 
//       * True - RefOrCollection of a reference type and object is not found in the data base.
//       *False - When RefOrCollection is not of a reference type or the object is found in the data base.
//
Function DeleteBrokenRefs(RefOrCollection)
	
	Type = TypeOf(RefOrCollection);
	
	If Type = Type("Undefined")
		Or Type = Type("Boolean")
		Or Type = Type("String")
		Or Type = Type("Number")
		Or Type = Type("Date") Then // Optimization - frequently used primitive types.
		
		Return False; // Not refs.
		
	ElsIf Type = Type("Array") Then
		
		Quantity = RefOrCollection.Count();
		For Number = 1 To Quantity Do
			ReverseIndex = Quantity - Number;
			Value = RefOrCollection[ReverseIndex];
			If DeleteBrokenRefs(Value) Then
				RefOrCollection.Delete(ReverseIndex);
			EndIf;
		EndDo;
		
		Return False; // Not refs.
		
	ElsIf Type = Type("Structure")
		Or Type = Type("Map") Then
		
		For Each KeyAndValue In RefOrCollection Do
			Value = KeyAndValue.Value;
			If DeleteBrokenRefs(Value) Then
				RefOrCollection.Insert(KeyAndValue.Key, Undefined);
			EndIf;
		EndDo;
		
		Return False; // Not refs.
		
	ElsIf Documents.AllRefsType().ContainsType(Type)
		Or Catalogs.AllRefsType().ContainsType(Type)
		Or Enums.AllRefsType().ContainsType(Type)
		Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		Or ChartsOfAccounts.AllRefsType().ContainsType(Type)
		Or ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		Or ExchangePlans.AllRefsType().ContainsType(Type)
		Or BusinessProcesses.AllRefsType().ContainsType(Type)
		Or Tasks.AllRefsType().ContainsType(Type) Then
		// Reference type, excluding BusinessProcessRoutePointRef.
		
		If RefOrCollection.IsEmpty() Then
			Return False; // Report empty.
		ElsIf ObjectAttributeValue(RefOrCollection, "Ref") = Undefined Then
			RefOrCollection = Undefined;
			Return True; // "Dead" reference.
		Else
			Return False; // Object is found.
		EndIf;
		
	Else
		
		Return False; // Not refs.
		
	EndIf;
	
EndFunction

// Deletes the setting from settings storage via its manager.
//
// Parameters:
//   StorageManager - StandardSettingsStorageManager - Storage from which the setting is deleted.
//   ObjectKey  - String       - Key of setting object. 
//                - Undefined - Settings for all objects are deleted.
//   SettingsKey - String       - Key of saved settings.
//                - Undefined - Settings with all keys are deleted.
//   UserName - String       - User’s name, their settings are imported.
//                   - Undefined - Settings of all users are deleted.
//
// See also:
//   SettingsStandardStorageManager.Delete in the syntax-assistant.
//   "Settings automatically saved in the system storage" in the syntax-assistant.
//
Procedure StorageDelete(StorageManager, ObjectKey, SettingsKey, UserName)
	
	If AccessRight("SaveUserData", Metadata) Then
		StorageManager.Delete(ObjectKey, SettingsKey(SettingsKey), UserName);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for work with the working date setting.

// Saves the setting of the user's working date.
//
// Parameters:
// NewWorkingDate - Date - Date that you should set as working date of a user.
// UserName - String - Name of the user for which the working date is set.
// 	If it is not specified, it is set for the current user.
//			
Procedure SetUserWorkingDate(NewWorkingDate, UserName = Undefined) Export

	ObjectKey = Upper("WorkingDate");
	
	CommonSettingsStorageSave(ObjectKey, , NewWorkingDate, , UserName);

EndProcedure

// Returns the value of the working date setting for a user.
//
// Parameters:
// UserName - String - Name of the user for which working date is requested.
// 	If it is not specified, it is set for the current user.
//
// Returns:
// Date - Value of the user's working date setting or an empty date if the setting is not specified.
//
Function UserWorkingDate(UserName = Undefined) Export

	ObjectKey = Upper("WorkingDate");

	Result = CommonSettingsStorageImport(ObjectKey, , '0001-01-01', , UserName);
	
	If TypeOf(Result) <> Type("Date") Then
		Result = '0001-01-01';
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the value of the working date setting for users
// or the current session date if user’s working date is not specified.
//
// Parameters:
// UserName - String - Name of the user for which working date is requested.
// 	If it is not specified, it is set for the current user.
//
// Returns:
// Date - Value of user working date setting or the current session date if the setting is not specified.
//
Function UserCurrentDate(UserName = Undefined) Export

	Result = UserWorkingDate(UserName);
	
	If Not ValueIsFilled(Result) Then
		Result = CurrentSessionDate();
	EndIf;
	
	Return BegOfDay(Result);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for work with tabular documents.

// Checks if the pass table documents fit in the printing page.
//
// Parameters:
//  Spreadsheet        - SpreadsheetDocument - tabular document.
//  AreasToPut   - Array, TabularDocument - array from the checked tables or tabular document. 
//  ResultOnError - Boolean - which one should be returned if an error occurs.
//
// Returns:
//   Boolean   - fit or no passed documents.
//
Function SpreadsheetDocumentFitsPage(Spreadsheet, AreasToPut, ResultOnError = True) Export

	Try
		Return Spreadsheet.CheckPut(AreasToPut);
	Except
		Return ResultOnError;
	EndTry;

EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions for work in the data separation mode.

// Sets an exclusive access to infobase (data area).
//
// When the use of separators
// in a session is enabled, it begins
// a transaction and sets exceptional controlled lock on locks space of all metadata objects included in the separator content.
//
// In other cases (for example, in the local mode) an exclusive mode is set. 
//
// Parameters:
//   CheckNoOtherSessions - Boolean - check if
//          there are no other user sessions where the separate equals to the current one.
//          If other sessions are found, an exception is thrown.
//          Parameter is used only during the work in the service model.
//
Procedure LockInfobase(Val CheckNoOtherSessions = True) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() 
		OR Not CommonUseReUse.CanUseSeparatedData() Then
		
		If Not ExclusiveMode() Then
			SetExclusiveMode(True);
		EndIf;
	Else
		If SubsystemExists("StandardSubsystems.SaaS") Then
			ModuleSaaSOperations = CommonModule("SaaSOperations");
			ModuleSaaSOperations.LockCurrentDataArea(CheckNoOtherSessions);
		Else
			Raise(NStr("en='Subsystem ""SaaS operations"" is not available';ru='Подсистема ""Работа в модели сервиса"" не доступна'"));
		EndIf;
	EndIf;
		
EndProcedure

// Removes exclusive access to infobase (data area).
//
// During the enabled use of separators in session,
// - if the call is done inside the exception
//   handler (from the Exceptions section...) cancels the transaction;
// - else commits the transaction.
//
// In other cases (for example, in local mode) clears the exclusive mode. 
//
Procedure UnlockInfobase() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() 
		OR Not CommonUseReUse.CanUseSeparatedData() Then
		
		If ExclusiveMode() Then
			SetExclusiveMode(False);
		EndIf;
	Else
		If SubsystemExists("StandardSubsystems.SaaS") Then
			ModuleSaaSOperations = CommonModule("SaaSOperations");
			ModuleSaaSOperations.UnlockCurrentDataArea();
		Else
			Raise(NStr("en='Subsystem ""SaaS operations"" is not available';ru='Подсистема ""Работа в модели сервиса"" не доступна'"));
		EndIf;
	EndIf;
	
EndProcedure

// Sets the session separation.
//
// Parameters:
//   Use - Boolean - Use the DataArea separator in the session.
//   DataArea - Number - Value of the DataArea separator.
//
Procedure SetSessionSeparation(Val Use, Val DataArea = Undefined) Export
	
	WithInstallationOfSplitSession(Use, DataArea);
	
EndProcedure

// Returns the separator value of the current data area.
// In case the value is not set, an error occurs.
// 
// Returns: 
//   Separator value type - separator value of the current data area. 
// 
Function SessionSeparatorValue() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return 0;
	Else
		SeparatorValue = Undefined;
		OnReceivingValuesSeparatorSession(SeparatorValue);
		Return SeparatorValue;
	EndIf;
	
EndFunction

// Returns a check box of using the DataArea separator for the current session.
// 
// Returns: 
//   Boolean - True if the separation is used.
// 
Function UseSessionSeparator() Export
	
	UseSeparator = Undefined;
	WhenGettingUseSeparatorSession(UseSeparator);
	Return UseSeparator;
	
EndFunction

// Initialization procedure of the separated infobase.
// 
// Parameters:
//   TurnOnDataSeparation - Boolean - shows that the separation is enabled in the infobase.
//
Procedure SetParametersOfInfobaseSeparation(Val TurnOnDataSeparation = False) Export
	
	If TurnOnDataSeparation Then
		Constants.UseSeparationByDataAreas.Set(True);
	Else
		Constants.UseSeparationByDataAreas.Set(False);
	EndIf;
	
EndProcedure

// Records value of a reference type
// separated by the AuxiliaryDataSeparator separator with switching of the session separator to the record time.
//
// Parameters:
//  ObjectSupportData - AnyRef, ObjectDeletion - value of a reference type or ObjectDeletion.
//
Procedure AuxilaryDataWrite(ObjectSupportData) Export
	
	If SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		ModuleSaaSOperations.AuxilaryDataWrite(ObjectSupportData);
	Else
		ObjectSupportData.Write();
	EndIf;
	
EndProcedure

// Deletes value of a reference type separated
// by the AuxiliaryDataSeparator separator with switching of the session separator to the record time.
//
// Parameters:
//  ObjectSupportData - AnyRef - value of a reference type.
//
Procedure DeleteAuxiliaryData(ObjectSupportData) Export
	
	If SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		ModuleSaaSOperations.DeleteAuxiliaryData(ObjectSupportData);
	Else
		ObjectSupportData.Delete();
	EndIf;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Application interfaces versioning.

// Returns array of versions numbers supported by the remote system interface.
//
// Parameters:
//  Address - String - web-service address of the interfaces versioning;
//  User - String - user name;
//  Password - String - user's password;
//  Interface - String - interface name.
//
// Returns:
//   FixedArray - array of rows, each row is a presentation of interface version number. For
//                         example, 1.0.2.1".
//
// Useful example:
//   ConnectionParameters = New Structure;
//   ConnectionParameters.Insert("URL", "http://vsrvx/sm");
//   ConnectionParameters.Insert(UserName, ivanov);
//   VersionsArray = GetInterfaceVersions (ConnectionParameters, FilesPassService);
//
// Note: while receiving versions cache is used and
//  the time for its update is 24 hours. If for debugging it is required to update values in cache,
// earlier than this you should delete the following records from
// the ApplicationInterfacesCache information register.
//
Function GetInterfaceVersions(Val Address, Val User, Val Password = Undefined, Val Interface = Undefined) Export
	
	If TypeOf(Address) = Type("Structure") Then
		ConnectionParameters = Address;
		InterfaceName = User;
	Else
		ConnectionParameters = New Structure;
		ConnectionParameters.Insert("URL", Address);
		ConnectionParameters.Insert("UserName", User);
		ConnectionParameters.Insert("Password", Password);
		InterfaceName = Interface;
	EndIf;
	
	If Not ConnectionParameters.Property("URL") 
		Or Not ValueIsFilled(ConnectionParameters.URL) Then
		
		Raise(NStr("en='URL of the service is not specified.';ru='Не задан URL сервиса.'"));
	EndIf;
	
	ReceivingParameters = New Array;
	ReceivingParameters.Add(ConnectionParameters);
	ReceivingParameters.Add(InterfaceName);
	
	Return CommonUseReUse.CacheVersionsData(
		VersionCacheRecordID(ConnectionParameters.URL, InterfaceName), 
		Enums.ProgramInterfaceCacheDataTypes.InterfaceVersions, 
		ValueToXMLString(ReceivingParameters),
		True);
	
EndFunction

// Returns the array of versions numbers supported by the system interface connected via the external connection.
//
// Parameters:
//   ExternalConnection - COMObject - COM-connection object that is used for work with correspondent.
//   InterfaceName - String -.
//
// Returns:
//   FixedArray - array of rows, each row is a presentation of interface version number. For
//                         example, 1.0.2.1".
//
// Useful example:
//  Parameters = ...
//  ExternalConnection = CommonUse.SetExternalConnection(Parameters);
//  VersionsArray = CommonUse.GetInterfaceVersionsViaExternalConnection (ExternalConnection, DataExchange);
//
Function GetInterfaceVersionsViaExternalConnection(ExternalConnection, Val InterfaceName) Export
	Try
		XMLInterfaceVersions = ExternalConnection.StandardSubsystemsServer.SupportedVersions(InterfaceName);
	Except
		MessageString = NStr("en='Correspondent does not support the subsystems interfaces versioning. Error description: %1';
		|ru='Корреспондент не поддерживает версионирование интерфейсов подсистем. Описание ошибки: %1'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(NStr("en='Receive interface versions';ru='Получение версий интерфейса'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , MessageString);
		
		Return New FixedArray(New Array);
	EndTry;
	
	Return New FixedArray(ValueFromXMLString(XMLInterfaceVersions));
EndFunction

// Deletes versions cache records containing the
// specified row in the identifier. Name of the interface that
// is not used in the configuration any more can be used as a subrow.
//
// Parameters:
//  IDSearchSubstring - String - substring
// of identifiers search. Row can not contain
//   %, _ and [ characters
//
Procedure VersionCacheRecordDeletion(Val IDSearchSubstring) Export
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		Block.Add("InformationRegister.ProgramInterfaceCache");
		SearchSubstring = GenerateStringForSearchInQuery(IDSearchSubstring);

		QueryText =
			"SELECT
			|	TableCache.ID AS ID,
			|	TableCache.DataType AS DataType
			|FROM
			|	InformationRegister.ProgramInterfaceCache AS TableCache
			|WHERE
			|	TableCache.ID LIKE ""%" + SearchSubstring + "%""
			|		ESCAPE ""~""";
		
		Query = New Query(QueryText);
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			
			Record = InformationRegisters.ProgramInterfaceCache.CreateRecordManager();
			Record.ID = Selection.ID;
			Record.DataType = Selection.DataType;
			
			Record.Delete();
			
		EndDo;
		
		CommitTransaction();
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for events processor and call of optional subsystems.

// Returns True if "functional" subsystem exists in the configuration.
// It is intended to implement at the call of optional subsystem (conditional call).
//
// Clear the Include in command interface check box in “functional” subsystem.
//
// Parameters:
//  SubsystemFullName - String - full name of the
//                        metadata object subsystem without words Subsystem.and taking into account characters register.
//                        For example, StandardSubsystems.ReportsVariants.
//
// Example:
//
//  If CommonUse.SubsystemExists(StandardSubsystems.ReportsVariants)
//  	Then ModuleReportsVariants = CommonUse.CommonModule(ReportVariants);
//  	ReportsVariantsModule.<Method name>();
//  EndIf;
//
// Returns:
//  Boolean.
//
Function SubsystemExists(SubsystemFullName) Export
	
	NamesSubsystems = StandardSubsystemsReUse.NamesSubsystems();
	Return NamesSubsystems.Get(SubsystemFullName) <> Undefined;
	
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
		Module = WorkInSafeMode.EvalInSafeMode(Name);
	ElsIf StrOccurrenceCount(Name, ".") = 1 Then
		Return ManagerServerModule(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Common module %1 was not found.';ru='Общий модуль %1 не найден.'"), Name);
	EndIf;
	
	Return Module;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Receive handlers of server events.

// Returns the structure for adding mandatory event.
//
// Returns:
//  Structure - 
//    * EventName - String - event presentation.
//       Example: StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers.
//
//    * Required - Boolean if True, then it is required to announce handlers for this event.
//
Function NewEvent() Export
	
	Return New Structure("Name, Mandatory", "", False);

EndFunction

// Returns handlers of the specified server event.
//
// Parameters:
//  Event  - String,
//             for example, StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers.
//
// Returns:
//  FixedArray - with values of the FixedStructure type with properties:
//    * Version - String      - handler version, for example, "2.1.3.4". Empty row if not specified.
//    * Module - CommonModule - server common module.
// 
Function EventHandlers(Event) Export
	
	Return StandardSubsystemsReUse.HandlersOfServerEvent(Event, False);
	
EndFunction

// Returns the handlers of the specified server service event.
//
// Parameters:
//  Event  - String - for
//             example, StandardSubsystems.BasicFunctionality\OnDefineSupportedApplicationInterfacesVersions.
//
// Returns:
//  FixedArray with values of the FixedStructure type with properties:
//    * Version - String      - handler version, for example, "2.1.3.4". Empty row if not specified.
//    * Module - CommonModule - server common module.
// 
Function ServiceEventProcessor(Event) Export
	
	Return StandardSubsystemsReUse.HandlersOfServerEvent(Event, True);
	
EndFunction

// Updates data in the versions cache.
//
// Parameters:
//  ID      - String - identifier of cache record.
//  DataType          - EnumRef.ApplicationInterfacesCacheDataTypes - type of the updated data.
//  ReceivingParameters - Array - additional parameters of receiving data to cache.
//
Procedure RefreshVersionCacheData(Val ID, Val DataType, Val ReceivingParameters) Export
	
	SetPrivilegedMode(True);
	
	KeyStructure = New Structure("Identifier, DataType", ID, DataType);
	KeyVar = InformationRegisters.ProgramInterfaceCache.CreateRecordKey(KeyStructure);
	
	Try
		LockDataForEdit(KeyVar);
	Except
		// Data is already being updated from other session.
		Return;
	EndTry;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	TableCache.UpdateDate AS UpdateDate,
		|	TableCache.Data AS Data,
		|	TableCache.DataType AS DataType
		|FROM
		|	InformationRegister.ProgramInterfaceCache AS TableCache
		|WHERE
		|	TableCache.ID = &ID
		|	AND TableCache.DataType = &DataType";
	ID = ID;
	Query.SetParameter("ID", ID);
	Query.SetParameter("DataType", DataType);
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ProgramInterfaceCache");
		LockItem.SetValue("ID", ID);
		LockItem.SetValue("DataType", DataType);
		Block.Lock();
		
		Result = Query.Execute();
		
		// Do not hold the transaction for other sessions to read data.
		CommitTransaction();
		
		// Make sure that the data requires update.
		If Not Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			If Not VersionCacheRecordObsolete(Selection) Then
				UnlockDataForEdit(KeyVar);
				Return;
			EndIf;
			
		EndIf;
		
		Set = InformationRegisters.ProgramInterfaceCache.CreateRecordSet();
		Set.Filter.ID.Set(ID);
		Set.Filter.DataType.Set(DataType);
		
		Record = Set.Add();
		Record.ID = ID;
		Record.DataType = DataType;
		Record.UpdateDate = CurrentUniversalDate();
		
		Set.AdditionalProperties.Insert("ReceivingParameters", ReceivingParameters);
		Set.PrepareDataForWrite();
		
		Set.Write();
		
		UnlockDataForEdit(KeyVar);
		
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
		
		UnlockDataForEdit(KeyVar);
		
		Raise;
		
	EndTry;
	
EndProcedure

// Prepares data for application interfaces cache.
//
// Parameters:
//  DataType          - EnumRef.ApplicationInterfacesCacheDataTypes - type of the updated data.
//  ReceivingParameters - Array - additional parameters of receiving data to cache.
//
Function PrepareDataCacheVersions(Val DataType, Val ReceivingParameters) Export
	
	If DataType = Enums.ProgramInterfaceCacheDataTypes.InterfaceVersions Then
		Data = GetInterfaceVersionsToCache(ReceivingParameters[0], ReceivingParameters[1]);
	ElsIf DataType = Enums.ProgramInterfaceCacheDataTypes.WebServiceDetails Then
		Data = GetWSDL(ReceivingParameters[0], ReceivingParameters[1], ReceivingParameters[2], ReceivingParameters[3]);
	Else
		TextPattern = NStr("en='Unknown data type of versions cache: %1';ru='Неизвестный тип данных кэша версий: %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(TextPattern, DataType);
		Raise(MessageText);
	EndIf;
	
	Return Data;
	
EndFunction

// Returns the fact of versions cache record aging.
//
// Parameters:
//  Record - InformationRegisterRecordManager.ApplicationInterfacesCache - record, fact of
//                                                                     aging that should be checked.
//
// Returns:
//  Boolean - shows that the record is outdated.
//
Function VersionCacheRecordObsolete(Val Record) Export
	
	If Record.DataType = Enums.ProgramInterfaceCacheDataTypes.WebServiceDetails Then
		Return Not ValueIsFilled(Record.UpdateDate)
	Else
		Return Record.UpdateDate + 86400 < CurrentUniversalDate();
	EndIf;
	
EndFunction

// Generates the identifier of versions cache record from the server addresses  and the resource name.
//
// Parameters:
//  Address - String - server address.
//  Name   - String - resource name.
//
// Returns:
//  String - identifier of versions cache record.
//
Function VersionCacheRecordID(Val Address, Val Name) Export
	
	Return Address + "|" + Name;
	
EndFunction

// Function returns the WSDefinitions object created with the passed parameters.
//
// Note: cache is used while receiving definition
//  update of which is executed while changing the configuration version. If for the debugging it
//  is required to update the value in cache, earlier than this, you should delete it from the information register.
//  ApplicationInterfacesCache corresponding records.
//
// Parameters:
//  WSDLAddress       - String - wsdl location.
//  UserName - String - user name for the website login.
//  Password          - String - user's password.
//  Timeout         - Number  - timeout for receiving wsdl.
//
// Returns:
//  WSDefinitions 
//
Function WSDefinitions(Val WSDLAddress, Val UserName, Val Password, Val Timeout = 10) Export
	
	If Not SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Return New WSDefinitions(WSDLAddress, UserName, Password, ,Timeout);
	EndIf;
	
	ReceivingParameters = New Array;
	ReceivingParameters.Add(WSDLAddress);
	ReceivingParameters.Add(UserName);
	ReceivingParameters.Add(Password);
	ReceivingParameters.Add(Timeout);
	
	WSDLData = CommonUseReUse.CacheVersionsData(
		WSDLAddress, 
		Enums.ProgramInterfaceCacheDataTypes.WebServiceDetails, 
		ValueToXMLString(ReceivingParameters),
		False);
		
	WSDLFileName = GetTempFileName("wsdl");
	
	WSDLData.Write(WSDLFileName);
	
	Definitions = New WSDefinitions(WSDLFileName);
	
	Try
		DeleteFiles(WSDLFileName);
	Except
		WriteLogEvent(NStr("en='Receive WSDL';ru='Получение WSDL'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Definitions;
EndFunction

// Function returns WSProxy object created with the passed parameters.
//
// Parameters:
//  WSDLAddress           - String - wsdl location.
//  NamespaceURI - String - URI spaces of the web-service names.
//  ServiceName          - String - service name.
//  EndpointName - String - if it is not specified, it is generated as <ServiceName>Soap.
//  UserName     - String - user name for the website login.
//  Password              - String - user's password.
//  Timeout             - Number  - timeout for operations executed via the received proxy.
//
// Returns:
//  WSProxy
//
Function InternalWSProxy(Val WSDLAddress, Val NamespaceURI, Val ServiceName,
	Val EndpointName, Val UserName, Val Password, Val Timeout) Export
	
	WSDefinitions = CommonUseReUse.WSDefinitions(WSDLAddress, UserName, Password);
	
	If IsBlankString(EndpointName) Then
		EndpointName = ServiceName + "Soap";
	EndIf;
	
	InternetProxy = Undefined;
	If SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleGetFilesFromInternetClientServer = CommonModule("GetFilesFromInternetClientServer");
		InternetProxy = ModuleGetFilesFromInternetClientServer.GetProxy(WSDLAddress);
	EndIf;
	
	Proxy = New WSProxy(WSDefinitions, NamespaceURI, ServiceName, EndpointName, InternetProxy, Timeout);
	Proxy.User = UserName;
	Proxy.Password       = Password;
	
	Return Proxy;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Outdated procedures and functions.

// Outdated. You should use OnCreateAtServer.
Function OnCreateFormAtServer(Form, StandardProcessing, Cancel) Export
	
	Return Not OnCreateAtServer(Form, Cancel, StandardProcessing);
	
EndFunction

// Outdated. You should use ObjectAttributesValues.
Function GetAttributeValues(Ref, AttributeNames) Export

	Return ObjectAttributesValues(Ref, AttributeNames);
	
EndFunction

// Outdated. You should use ObjectAttributeValue.
Function GetAttributeValue(Ref, AttributeName) Export
	
	Return ObjectAttributeValue(Ref, AttributeName);
	
EndFunction 

// Outdated. You should use HasRefsToObject.
Function HasReferencesToObjectInInfobase(Val RefOrRefArray, Val SearchInServiceObjects = False) Export
	Return ThereAreRefsToObject(RefOrRefArray, SearchInServiceObjects);
EndFunction

// Outdated. You should use CommonUseClientServer.StructureKeysToString.
Function StructureKeysToString(Structure, Delimiter = ",") Export
	
	Return CommonUseClientServer.StructureKeysToString(Structure, Delimiter);
	
EndFunction

// Outdated. You should use WorkInSafeMode.ExecuteConfigurationMethod().
Procedure RunSafely(ExportProcedureName, Parameters = Undefined, DataArea = Undefined) Export
	
	CompletedSetSplitSession = False;
	If CommonUseReUse.DataSeparationEnabled() Then
		If Not CommonUseReUse.SessionWithoutSeparator() Then
			If DataArea = Undefined Then
				DataArea = SessionSeparatorValue();
			Else 
				If DataArea <> SessionSeparatorValue() Then
					Raise(NStr("en='Cannot access data from another data area in this session.';ru='В данном сеансе недопустимо обращение к данным из другой области данных!'"));
				EndIf;
			EndIf;
		EndIf;
		If DataArea <> Undefined
			AND (Not UseSessionSeparator() OR DataArea <> SessionSeparatorValue()) Then
			SetSessionSeparation(True, DataArea);
			CompletedSetSplitSession = True;
		EndIf;
	EndIf;
	
	Try
		
		WorkInSafeMode.ExecuteConfigurationMethod(ExportProcedureName, Parameters);
		
		If CompletedSetSplitSession Then
			SetSessionSeparation(False);
		EndIf;
		
	Except
		
		If CompletedSetSplitSession Then
			SetSessionSeparation(False);
		EndIf;
		
		Raise;
		
	EndTry;
	
EndProcedure

// Outdated. You should use WorkInSafeMode.CheckConfigurationMethodName().
Function CheckExportProcedureName(Val ExportProcedureName, MessageText) Export
	
	Try
		WorkInSafeMode.ValidateConfigurationMethodName(ExportProcedureName);
		Return True;
	Except
		MessageText = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

Procedure NewMetadataObjectCollectionRow(Name, Synonym, Picture, ObjectPicture, Tab)
	
	NewRow = Tab.Add();
	NewRow.Name               = Name;
	NewRow.Synonym           = Synonym;
	NewRow.Picture          = Picture;
	NewRow.ObjectPicture   = ObjectPicture;
	
EndProcedure

Function GetInterfaceVersionsToCache(Val ConnectionParameters, Val InterfaceName)
	
	If Not ConnectionParameters.Property("URL") 
		Or Not ValueIsFilled(ConnectionParameters.URL) Then
		
		Raise(NStr("en='URL of the service is not specified.';ru='Не задан URL сервиса.'"));
	EndIf;
	
	If ConnectionParameters.Property("UserName")
		AND ValueIsFilled(ConnectionParameters.UserName) Then
		
		UserName = ConnectionParameters.UserName;
		
		If ConnectionParameters.Property("Password") Then
			UserPassword = ConnectionParameters.Password;
		Else
			UserPassword = Undefined;
		EndIf;
		
	Else
		UserName = Undefined;
		UserPassword = Undefined;
	EndIf;
	
	ServiceAddress = ConnectionParameters.URL + "/ws/InterfaceVersion?wsdl";
	
	VersioningProxy = WSProxy(ServiceAddress, "http://www.1c.ru/SaaS/1.0/WS",
		"InterfaceVersion", , UserName, UserPassword, 3);
		
	XDTOArray = VersioningProxy.GetVersions(InterfaceName);
	If XDTOArray = Undefined Then
		Return New FixedArray(New Array);
	Else	
		Serializer = New XDTOSerializer(VersioningProxy.XDTOFactory);
		Return New FixedArray(Serializer.ReadXDTO(XDTOArray));
	EndIf;
	
EndFunction

Function GetWSDL(Val Address, Val UserName, Val Password, Val Timeout)
	
	ReceivingParameters = New Structure;
	If Not IsBlankString(UserName) Then
		ReceivingParameters.Insert("User", UserName);
		ReceivingParameters.Insert("Password", Password);
	EndIf;
	ReceivingParameters.Insert("Timeout", Timeout);
	
	FileDescription = Undefined;
	
	OnFileExportAtServer(Address, ReceivingParameters, FileDescription);
	
	If Not FileDescription.Status Then
		Raise(NStr("en='An error occurred when receiving a description file of the web service:';ru='Ошибка получения файла описания web-сервиса:'") + Chars.LF + FileDescription.ErrorInfo)
	EndIf;
	
	// Try to create WS definitions on the basis of a received file.
	Definitions = New WSDefinitions(FileDescription.Path);
	If Definitions.Services.Count() = 0 Then
		MessagePattern = NStr("en='An error occurred while receiving the file of web service description: 
		|The received file does not contain any service description.
		|
		|Description file address may be incorrect: %1';
		|ru='Ошибка получения файла описания web-сервиса: 
		|В полученном файле не содержится ни одного описания сервиса.
		|
		|Возможно, адрес файла описания указан неверно: %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Address);
		Raise(MessageText);
	EndIf;
	Definitions = Undefined;
	
	FileData = New BinaryData(FileDescription.Path);
	
	Try
		DeleteFiles(FileDescription.Path);
	Except
		WriteLogEvent(NStr("en='Receive WSDL';ru='Получение WSDL'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return FileData;
	
EndFunction

Function CollectionName(FullName)
	
	DotPosition = Find(FullName, ".");
	
	If DotPosition > 0 Then
		Return Left(FullName, DotPosition - 1);
	EndIf;
	
	Return "";
	
EndFunction

Procedure CheckingDataFixed(Data, DataInValueOfFixedTypes = False)
	
	DataType = TypeOf(Data);
	
	If DataType = Type("ValueStorage")
	 OR DataType = Type("FixedArray")
	 OR DataType = Type("FixedStructure")
	 OR DataType = Type("FixedMap") Then
		
		Return;
	EndIf;
	
	If DataInValueOfFixedTypes Then
		
		If DataType = Type("Boolean")
		 OR DataType = Type("String")
		 OR DataType = Type("Number")
		 OR DataType = Type("Date")
		 OR DataType = Type("Undefined")
		 OR DataType = Type("UUID")
		 OR DataType = Type("Null")
		 OR DataType = Type("Type")
		 OR DataType = Type("ValueStorage")
		 OR DataType = Type("CommonModule")
		 OR DataType = Type("MetadataObject")
		 OR DataType = Type("XDTOValueType")
		 OR DataType = Type("XDTOObjectType")
		 OR IsReference(DataType) Then
			
			Return;
		EndIf;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='An error occurred in the FixedData function of the CommonUse common module. Data of the %1 type can not be recorded.';
			 |ru='Ошибка в функции ФиксированныеДанные общего модуля ОбщегоНазначения. Данные типа %1 не могут быть зафиксированы.'"),
		String(DataType) );
	
EndProcedure

Procedure AddRefSearchExclusions(RefsSearchExceptions, ExceptionArray)
	For Each ArrayElement In ExceptionArray Do
		If TypeOf(ArrayElement) = Type("String") Then
			ItemMetadata = Metadata.FindByFullName(ArrayElement);
		Else
			ItemMetadata = ArrayElement;
		EndIf;
		
		ParentMetadata = ItemMetadata.Parent();
		
		// Registration of excluded metadata object entirely (all references that it can contain).
		If TypeOf(ParentMetadata) = Type("ConfigurationMetadataObject") Then
			RefsSearchExceptions.Insert(ItemMetadata, "*");
			Continue;
		EndIf;
		
		// Registration of the excluded attribute of metadata object.
		RelativePathToAttribute = ItemMetadata.Name;
		ParentsParent = ParentMetadata.Parent();
		While TypeOf(ParentsParent) <> Type("ConfigurationMetadataObject") Do
			RelativePathToAttribute = ParentMetadata.Name + "." + RelativePathToAttribute;
			ParentMetadata = ParentsParent;
			ParentsParent   = ParentMetadata.Parent();
		EndDo;
		
		PathsToAttributes = RefsSearchExceptions.Get(ParentMetadata);
		If PathsToAttributes = Undefined Then
			PathsToAttributes = New Array;
		ElsIf PathsToAttributes = "*" Then
			Continue; // - Skip if the whole metadata object is already excluded.
		EndIf;
		PathsToAttributes.Add(RelativePathToAttribute);
		
		RefsSearchExceptions.Insert(ParentMetadata, PathsToAttributes);
	EndDo;
EndProcedure

// Returns settings key string not exceeding the allowed length.
// Checks the string length at login and in case it exceeds 128, converts its end to
// the short version using MD5 algorithm, so the string length becomes equal to 128 characters.
// If the source string is less than 128 characters, it is returned as it is.
//
// Parameters:
//  String - String - String of arbitrary length.
//
Function SettingsKey(Val String)
	Result = String;
	If StrLen(String) > 128 Then // Key of more than 128 characters will cause an exception when accessing the settings storage.
		Result = Left(String, 96);
		DataHashing = New DataHashing(HashFunction.MD5);
		DataHashing.Append(Mid(String, 97));
		Result = Result + StrReplace(DataHashing.HashSum, " ", "");
	EndIf;
	Return Result;
EndFunction

// Returns manager server module by the object name.
Function ManagerServerModule(Name)
	ObjectFound = False;
	
	NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Name, ".");
	If NameParts.Count() = 2 Then
		
		KindName = Upper(NameParts[0]);
		ObjectName = NameParts[1];
		
		If KindName = Upper(TypeNameConstants()) Then
			If Metadata.Constants.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameInformationRegisters()) Then
			If Metadata.InformationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameAccumulationRegisters()) Then
			If Metadata.AccumulationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameOfAccountingRegisters()) Then
			If Metadata.AccountingRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(NameKindCalculationRegisters()) Then
			If Metadata.CalculationRegisters.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameCatalogs()) Then
			If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameDocuments()) Then
			If Metadata.Documents.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameReports()) Then
			If Metadata.Reports.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameDataProcessors()) Then
			If Metadata.DataProcessors.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(BusinessProcessTypeName()) Then
			If Metadata.BusinessProcesses.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameDocumentJournals()) Then
			If Metadata.DocumentJournals.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameTasks()) Then
			If Metadata.Tasks.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameChartsOfAccounts()) Then
			If Metadata.ChartsOfAccounts.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameExchangePlans()) Then
			If Metadata.ExchangePlans.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameChartsOfCharacteristicTypes()) Then
			If Metadata.ChartsOfCharacteristicTypes.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		ElsIf KindName = Upper(TypeNameChartsOfCalculationTypes()) Then
			If Metadata.ChartsOfCalculationTypes.Find(ObjectName) <> Undefined Then
				ObjectFound = True;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not ObjectFound Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 metadata object is not found or manager module receipt is not supported for it.';
				 |ru='Объект метаданных %1 не найден, либо для него не поддерживается получение модуля менеджера.'"), Name);
	EndIf;
	
	Module = WorkInSafeMode.EvalInSafeMode(Name);
	
	Return Module;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Receive file from the Internet by http(s) or ftp protocol and save it to the temporary file.
//
// Parameters:
//   URL                  - String - file url in format.
//                                   [Protocol://]<Server>/<Path to file on server>.
//   ReceivingParameters   - Structure with properties.
//     PathForSave    - String - path on server (including attachment file name) to save imported file.
//     User         - String - user on whose behalf the connection is established.
//     Password               - String - password of the user from which the connection is set.
//     Port                 - Number  - server port with which the connection is set.
//     SecureConnection - Boolean - in case of http import
//                                     the check box shows that the connection should be executed via https.
//     PassiveConnection  - Boolean - for the ftp import, the
//                                     flag shows that connection must be passive (or active).
//   ReturnValue - (output parameter).
//     Structure, with properties.
//       Status - Boolean - key is always present in the structure, values.
//                         True - function call is complete successfully.
//                         False   - function call is complete unsuccessfully.
//       Path   - String - file path on server, key
//                         is used only if status is True.
//       ErrorInfo - String - error message if the state is False.
//
Procedure OnFileExportAtServer(Val Address, Val ReceivingParameters, ReturnValue)
	
	If SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleGetFilesFromInternet = CommonModule("GetFilesFromInternet");
		ReturnValue = ModuleGetFilesFromInternet.ExportFileAtServer(Address, ReceivingParameters);
	EndIf;
	
EndProcedure

// Sets the session separation.
//
// Parameters:
// Use - Boolean - Use the DataArea separator in the session.
// DataArea - Number - Value of the DataArea separator.
//
Procedure WithInstallationOfSplitSession(Val Use, Val DataArea = Undefined)
	
	If SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		ModuleSaaSOperations.SetSessionSeparation(Use, DataArea);
	EndIf;
	
EndProcedure

// Returns the separator value of the current data area.
// In case the value is not set, an error occurs.
// 
// Parameters:
//  SeparatorValue - Separator value of the current data area. Return parameter.
//
Procedure OnReceivingValuesSeparatorSession(SeparatorValue)
	
	If SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		SeparatorValue = ModuleSaaSOperations.SessionSeparatorValue();
	Else
		Raise(NStr("en='Subsystem ""SaaS operations"" is not available';ru='Подсистема ""Работа в модели сервиса"" не доступна'"));
	EndIf;
	
EndProcedure

// Returns a check box of using the DataArea separator for the current session.
// 
// Parameters:
// UseSeparator - Boolean - True separation is used, otherwise, no. Return parameter.
// 
Procedure WhenGettingUseSeparatorSession(UseSeparator) Export
	
	If SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		UseSeparator = ModuleSaaSOperations.UseSessionSeparator();
	Else
		Raise(NStr("en='Subsystem ""SaaS operations"" is not available';ru='Подсистема ""Работа в модели сервиса"" не доступна'"));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURES AND FUNCTIONS References replacement.

Function TypeDescriptionRecordsKeys()
	
	AddTypes = New Array;
	For Each Meta In Metadata.InformationRegisters Do
		AddTypes.Add(Type("InformationRegisterRecordKey." + Meta.Name));
	EndDo;
	For Each Meta In Metadata.AccumulationRegisters Do
		AddTypes.Add(Type("AccumulationRegisterRecordKey." + Meta.Name));
	EndDo;
	For Each Meta In Metadata.AccountingRegisters Do
		AddTypes.Add(Type("AccountingRegisterRecordKey." + Meta.Name));
	EndDo;
	For Each Meta In Metadata.CalculationRegisters Do
		AddTypes.Add(Type("CalculationRegisterRecordKey." + Meta.Name));
	EndDo;
	
	Return New TypeDescription(AddTypes); 
EndFunction

Procedure PlaceUsagePlaces(Val Configuration, Val Ref, Val TargetRef, Val SearchTable, MarkupResult = Undefined)
	SetPrivilegedMode(True);

	TypeRecordKey  = Configuration.TypeRecordKey;
	MetaConstants  = Configuration.MetaConstants;
	AllRefsType   = Configuration.AllRefsType;
	TypeRecordsKey = Configuration.TypeRecordKey;
	
	// Set the order of the known and check if there are unrecognized objects.
	RefFilter = New Structure("Ref, ReplacementKey", Ref, "");
	
	MarkupResult = New Structure;
	MarkupResult.Insert("UsagePlaces", SearchTable.FindRows(RefFilter) );
	MarkupResult.Insert("MarkupErrors",     New Array);
	
	For Each UsagePlace In MarkupResult.UsagePlaces Do
		LocationMetadata = UsagePlace.Metadata;
		
		If UsagePlace.AuxiliaryData Then
			// Do not process dependent data at all.
			Continue;
			
		ElsIf MetaConstants.Contains(LocationMetadata) Then
			UsagePlace.ReplacementKey = "Constant";
			UsagePlace.TargetRef = TargetRef;
			
		Else
			DataType = TypeOf(UsagePlace.Data);
			If AllRefsType.ContainsType(DataType) Then
				UsagePlace.ReplacementKey = "Object";
				UsagePlace.TargetRef = TargetRef;
				
			ElsIf TypeRecordsKey.ContainsType(DataType) Then
				UsagePlace.ReplacementKey = "RecordKey";
				UsagePlace.TargetRef = TargetRef;
				
			Else
				// Unknown object for references replacement.
				Text = NStr("en='Unknown data type %1 for replacement %2';ru='Неизвестный тип данных %1 для проведения замены %2'");
				Text = StrReplace(Text, "%1", String(UsagePlace.Data));
				Text = StrReplace(Text, "%2", String(Ref));
				MarkupResult.MarkupErrors.Add(
					New Structure("Object, Text", UsagePlace.Data, Text));
				
				Break;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure ReplaceInConstant(Results, Val UsagePlace, Val WriteParameters, Val InternalTransaction = True)
	
	SetPrivilegedMode(True);
	
	Data = UsagePlace.Data;
	Meta   = UsagePlace.Metadata;
	
	DataPresentation = String(Data);
	
	// Immediately replace all this data.
	Filter = New Structure("Data, ReplacementKey", Data, "Constant");
	ProcessedRows = UsagePlace.Owner().FindRows(Filter);
	
	ActionState = "";
	
	If InternalTransaction Then
		BeginTransaction();
		
		Block = New DataLock;
		Block.Add(Meta.FullName());
	
		Try
			Block.Lock();
		Except
			// Add record about an unsuccessful attempt to lock the result.
			Error = NStr("en='Cannot lock constant %1';ru='Не удалось заблокировать константу %1'");
			Error = StrReplace(Error, "%1", DataPresentation);
			
			ActionState = "LockError";
		EndTry;
		
	EndIf;	// Need for lock
	
	If ActionState = "" Then
		Manager = Constants[Meta.Name].CreateValueManager();
		Manager.Read();
		
		ReplacementMade = True;
		For Each String In ProcessedRows Do
			If Manager.Value = String.Ref Then
				Manager.Value = String.TargetRef;
				ReplacementMade = True;
			EndIf;
		EndDo;
		
		If ReplacementMade Then
			// Try to save
			If Not WriteParameters.PrivilegedRecord Then
				SetPrivilegedMode(False);
			EndIf;
			
			Try
				WriteObject(Manager, WriteParameters);
			Except
				// Save the reason
				Information = ErrorInfo();
				WriteLogEvent(EventLogMonitorEventRefsReplacements(),
					EventLogLevel.Error, Meta, DetailErrorDescription(Information));
				
				// Add record about record error to result.
				ErrorDescription = BriefErrorDescription(Information);
				If IsBlankString(ErrorDescription) Then
					ErrorDescription = Information.Definition;
				EndIf;
				
				Error = NStr("en='Cannot write %1 due to: %2';ru='Не удалось записать %1 по причине: %2'");
				Error = StrReplace(Error, "%1", DataPresentation);
				Error = StrReplace(Error, "%2", ErrorDescription);
				
				For Each String In ProcessedRows Do
					AddReplacementResult(Results, String.Ref, 
						ReplacementErrorDescription("RecordingError", Data, DataPresentation, Error));
				EndDo;
				
				ActionState = "RecordingError";
			EndTry;
			
			If Not WriteParameters.PrivilegedRecord Then
				SetPrivilegedMode(True);
			EndIf;
			
		EndIf;
	EndIf;
	
	If InternalTransaction Then
		If ActionState = "" Then
			CommitTransaction();
		Else
			RollbackTransaction();
		EndIf;
	EndIf;
	
	// Mark as processed
	For Each String In ProcessedRows Do
		String.ReplacementKey = "";
	EndDo;

EndProcedure

Procedure ReplaceInObject(Results, Val UsagePlace, Val WriteParameters, Val InternalTransaction = True)
	
	SetPrivilegedMode(True);
	
	Data = UsagePlace.Data;
	Meta   = UsagePlace.Metadata;
	
	DataPresentation = SubjectString(Data);
	
	// Immediately replace all this data.
	Filter = New Structure("Data, ReplacementKey", Data, "Object");
	ProcessedRows = UsagePlace.Owner().FindRows(Filter);
	
	SequencesDescription = SequencesDescription(Meta);
	MovementsDescription            = MovementsDescription(Meta);

	ActionState = "";
	
	If InternalTransaction Then
		// Process all contiguous data simultaneously.
		BeginTransaction();
		
		Block = New DataLock;
		
		// Item itself
		Block.Add(Meta.FullName()).SetValue("Ref", Data);
		
		// RegisterRecords 
		For Each Item In MovementsDescription Do
			// All by the registrar
			Block.Add(Item.SpaceLock + ".RecordSet").SetValue("Recorder", Data);
			
			// All candidates - dimensions for saving totals.
			For Each KeyValue In Item.DimensionList Do
				DimensionType  = KeyValue.Value;
				For Each UsagePlace In ProcessedRows Do
					CurrentRef = UsagePlace.Ref;
					If DimensionType.ContainsType(TypeOf(CurrentRef)) Then
						Block.Add(Item.SpaceLock).SetValue(KeyValue.Key, UsagePlace.Ref);
					EndIf;
				EndDo;
			EndDo;
		EndDo;
		
		// Sequences
		For Each Item In SequencesDescription Do
			Block.Add(Item.SpaceLock).SetValue("Recorder", Data);
			
			For Each KeyValue In Item.DimensionList Do
				DimensionType  = KeyValue.Value;
				For Each UsagePlace In ProcessedRows Do
					CurrentRef = UsagePlace.Ref;
					If DimensionType.ContainsType(TypeOf(CurrentRef)) Then
						Block.Add(Item.SpaceLock).SetValue(KeyValue.Key, CurrentRef);
					EndIf;
				EndDo;
			EndDo;
		EndDo;
		
		Try
			Block.Lock();
		Except
			// Add record about an unsuccessful attempt to lock the result.
			Error = NStr("en='Unable to lock one or several objects from the list %1';ru='Не удалось заблокировать один или несколько объектов из списка %1'");
			Error = StrReplace(Error, "%1", LockListDescription(Block));
			For Each String In ProcessedRows Do
				AddReplacementResult(Results, String.Ref, 
					ReplacementErrorDescription("LockError", Data, DataPresentation, Error));
			EndDo;
			
			ActionState = "LockError";
		EndTry;
		
	EndIf;	// Need for lock
	
	If ActionState = "" Then
		RecordObjects = ChangedObjectsOnReplacementInObject(Data, ProcessedRows, MovementsDescription, SequencesDescription);
		
		// Try to save, the object itself comes last.
		If Not WriteParameters.PrivilegedRecord Then
			SetPrivilegedMode(False);
		EndIf;
		
		Try
			If WriteParameters.DoNotCheck Then
				// Record without business logic control.
				For Each KeyValue In RecordObjects Do
					WriteObject(KeyValue.Key, WriteParameters);
				EndDo;
				
			Else
				// First record without control – to remove cycle refs.
				WriteParameters.DoNotCheck = True;
				For Each KeyValue In RecordObjects Do
					WriteObject(KeyValue.Key, WriteParameters);
				EndDo;
				
				// Second record with control
				WriteParameters.DoNotCheck = False;
				For Each KeyValue In RecordObjects Do
					WriteObject(KeyValue.Key, WriteParameters);
				EndDo;
			EndIf;
			
		Except
			// Save the reason
			Information = ErrorInfo();
			WriteLogEvent(EventLogMonitorEventRefsReplacements(),
				EventLogLevel.Error, Meta, DetailErrorDescription(Information));
				
			ErrorDescription = BriefErrorDescription(Information);
			If IsBlankString(ErrorDescription) Then
				ErrorDescription = Information.Definition;
			EndIf;
			
			// Add record about record error to result.
			Error = NStr("en='Cannot write %1 due to: %2';ru='Не удалось записать %1 по причине: %2'");
			Error = StrReplace(Error, "%1", DataPresentation);
			Error = StrReplace(Error, "%2", ErrorDescription);
			
			For Each String In ProcessedRows Do
				AddReplacementResult(Results, String.Ref, 
					ReplacementErrorDescription("RecordingError", Data, DataPresentation, Error)
				);
			EndDo;
			
			ActionState = "RecordingError";
		EndTry;
		
		If Not WriteParameters.PrivilegedRecord Then
			SetPrivilegedMode(True);
		EndIf;
		
		// Delete processed movements and sequences from the search table.
	EndIf;
	
	If InternalTransaction Then
		If ActionState = "" Then
			CommitTransaction();
		Else
			RollbackTransaction();
		EndIf;
	EndIf;
	
	// Mark as processed
	For Each String In ProcessedRows Do
		String.ReplacementKey = "";
	EndDo;
	
EndProcedure

Procedure ReplaceInSet(Results, Val UsagePlace, Val WriteParameters, Val InternalTransaction = True)
	SetPrivilegedMode(True);
	
	Data = UsagePlace.Data;
	Meta   = UsagePlace.Metadata;
	
	DataPresentation = String(Data);
	
	// Immediately replace all this data.
	Filter = New Structure("Data, ReplacementKey", Data, "RecordKey");
	ProcessedRows = UsagePlace.Owner().FindRows(Filter);
	
	DescriptionOfSet = RecordKeyDescription(Meta);
	RecordSet = DescriptionOfSet.RecordSet;
	
	SubstitutionsPairs = New Map;
	For Each String In ProcessedRows Do
		SubstitutionsPairs.Insert(String.Ref, String.TargetRef);
	EndDo;
	
	ActionState = "";
	
	If InternalTransaction Then
		BeginTransaction();
		
		// Lock and prepare set.
		Block = New DataLock;
		For Each KeyValue In DescriptionOfSet.DimensionList Do
			DimensionType = KeyValue.Value;
			Name          = KeyValue.Key;
			Value     = Data[Name];
			
			For Each String In ProcessedRows Do
				CurrentRef = String.Ref;
				If DimensionType.ContainsType(TypeOf(CurrentRef)) Then
					Block.Add(DescriptionOfSet.SpaceLock).SetValue(Name, CurrentRef);
				EndIf;
			EndDo;
			
			RecordSet.Filter[Name].Set(Value);
		EndDo;
		
		Try
			Block.Lock();
		Except
			// Add record about an unsuccessful attempt to lock the result.
			Error = NStr("en='Cannot lock set %1';ru='Не удалось заблокировать набор %1'");
			Error = StrReplace(Error, "%1", DataPresentation);
			
			ActionState = "LockError";
		EndTry;
		
	EndIf;	// Need for lock
		
	If ActionState = "" Then
		RecordSet.Read();
		ReplaceInStringsCollection(RecordSet, DescriptionOfSet.FieldList, SubstitutionsPairs);
		
		If RecordSet.Modified() Then
			// Try to save
			If Not WriteParameters.PrivilegedRecord Then
				SetPrivilegedMode(False);
			EndIf;
			
			Try
				WriteObject(RecordSet, WriteParameters);
			Except
				// Save the reason
				Information = ErrorInfo();
				WriteLogEvent(EventLogMonitorEventRefsReplacements(),
					EventLogLevel.Error, Meta, DetailErrorDescription(Information));
					
				ErrorDescription = BriefErrorDescription(Information);
				If IsBlankString(ErrorDescription) Then
					ErrorDescription = Information.Definition;
				EndIf;
				
				// Add record about record error to result.
				Error = NStr("en='Cannot write %1 due to: %2';ru='Не удалось записать %1 по причине: %2'");
				Error = StrReplace(Error, "%1", DataPresentation);
				Error = StrReplace(Error, "%2", ErrorDescription);
				
				For Each String In ProcessedRows Do
					AddReplacementResult(Results, String.Ref, 
						ReplacementErrorDescription("RecordingError", Data, DataPresentation, Error)
					);
				EndDo;
				
				ActionState = "RecordingError";
			EndTry;
			
			If Not WriteParameters.PrivilegedRecord Then
				SetPrivilegedMode(True);
			EndIf;
			
		EndIf;
	EndIf;
	
	If InternalTransaction Then
		If ActionState = "" Then
			CommitTransaction();
		Else
			RollbackTransaction();
		EndIf;
	EndIf;
	
	// Mark as processed
	For Each String In ProcessedRows Do
		String.ReplacementKey = "";
	EndDo;
	
EndProcedure

Function ChangedObjectsOnReplacementInObject(Val Data, Val ProcessedRows, Val MovementsDescription, Val SequencesDescription)
	SetPrivilegedMode(True);
	
	// Return changed processed objects.
	modified = New Map;
	
	// Read
	Definition = ObjectDescription(Data.Metadata());
	Try
		Object = Data.GetObject();
	Except
		// It has already been processed with errors.
		Object = Undefined;
	EndTry;
	
	If Object = Undefined Then
		Return modified;
	EndIf;
	
	For Each MovementDescription In MovementsDescription Do
		MovementDescription.RecordSet.Filter.Recorder.Set(Data);
		MovementDescription.RecordSet.Read();
	EndDo;
	
	For Each SequenceDescription In SequencesDescription Do
		SequenceDescription.RecordSet.Filter.Recorder.Set(Data);
		SequenceDescription.RecordSet.Read();
	EndDo;
	
	// Replace all variants at once.
	SubstitutionsPairs = New Map;
	For Each UsagePlace In ProcessedRows Do
		SubstitutionsPairs.Insert(UsagePlace.Ref, UsagePlace.TargetRef);
	EndDo;
	
	// Attributes
	For Each KeyValue In Definition.Attributes Do
		Name = KeyValue.Key;
		TargetRef = SubstitutionsPairs[ Object[Name] ];
		If TargetRef <> Undefined Then
			Object[Name] = TargetRef;
		EndIf;
	EndDo;
		
	// Standard attributes
	For Each KeyValue In Definition.StandardAttributes Do
		Name = KeyValue.Key;
		TargetRef = SubstitutionsPairs[ Object[Name] ];
		If TargetRef <> Undefined Then
			Object[Name] = TargetRef;
		EndIf;
	EndDo;
		
	// Tabular Sections
	For Each Item In Definition.TabularSections Do
		ReplaceInStringsCollection(Object[Item.Name], Item.FieldList, SubstitutionsPairs);
	EndDo;
	
	// Standard tabular sections.
	For Each Item In Definition.StandardTabularSections Do
		ReplaceInStringsCollection(Object[Item.Name], Item.FieldList, SubstitutionsPairs);
	EndDo;
		
	// RegisterRecords
	For Each MovementDescription In MovementsDescription Do
		ReplaceInStringsCollection(MovementDescription.RecordSet, MovementDescription.FieldList, SubstitutionsPairs);
	EndDo;
	
	// Sequences
	For Each SequenceDescription In SequencesDescription Do
		ReplaceInStringsCollection(SequenceDescription.RecordSet, SequenceDescription.FieldList, SubstitutionsPairs);
	EndDo;
	
	For Each MovementDescription In MovementsDescription Do
		If MovementDescription.RecordSet.Modified() Then
			modified.Insert(MovementDescription.RecordSet, False);
		EndIf;
	EndDo;
	
	For Each SequenceDescription In SequencesDescription Do
		If SequenceDescription.RecordSet.Modified() Then
			modified.Insert(SequenceDescription.RecordSet, False);
		EndIf;
	EndDo;
	
	// The object itself is the last - for possible posting.
	If Object.Modified() Then
		modified.Insert(Object, Definition.CanBePosted);
	EndIf;
	
	Return modified;
EndFunction

Procedure DeleteRefsWithMarkup(DeletionResult, Val RefsList, Val WriteParameters, Val InternalTransaction = True)
	
	DeleteRefsNotExclusively(DeletionResult, RefsList, WriteParameters, InternalTransaction, False);
	
EndProcedure

Procedure DeleteRefsDirectly(DeletionResult, Val RefsList, Val WriteParameters, Val InternalTransaction = True)
	
	DeleteRefsNotExclusively(DeletionResult, RefsList, WriteParameters, InternalTransaction, True);
	
EndProcedure

Procedure DeleteRefsNotExclusively(DeletionResult, Val RefsList, Val WriteParameters, Val InternalTransaction, Val DeleteDirectly)
	
	SetPrivilegedMode(True);
	
	ToDelete = New Array;
	
	If InternalTransaction Then
		BeginTransaction();
	EndIf;
		
	For Each Ref In RefsList Do
		Block = New DataLock;
		Block.Add(Ref.Metadata().FullName()).SetValue("Ref", Ref);
	EndDo;
		
	For Each Ref In RefsList Do
		REFPRESENTATION = SubjectString(Ref);
		
		Try 
			Block.Lock();
			ToDelete.Add(Ref);
		Except
			AddReplacementResult(DeletionResult, Ref, 
				ReplacementErrorDescription("LockError", Ref, REFPRESENTATION, NStr("en='An error occurred when locking reference for deletion.';ru='Ошибка блокирования ссылки для удаления'")));
		EndTry
	EndDo;
		
	SearchTable = UsagePlaces(ToDelete);
	Filter = New Structure("Ref");
	
	For Each Ref In ToDelete Do
		REFPRESENTATION = SubjectString(Ref);
		
		Filter.Ref = Ref;
		UsagePlaces = SearchTable.FindRows(Filter);
		
		IndexOf = UsagePlaces.UBound();
		While IndexOf >= 0 Do
			If UsagePlaces[IndexOf].AuxiliaryData Then
				UsagePlaces.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
		If UsagePlaces.Count() > 0 Then
			// It was changed, can not be deleted.
			AddChangedObjectsReplacementResults(DeletionResult, UsagePlaces);
			Continue;
		EndIf;
		
		Object = Ref.GetObject();
		If Object = Undefined Then
			// Already deleted
			Continue;
		EndIf;
			
		If Not WriteParameters.PrivilegedRecord Then
			SetPrivilegedMode(False);
		EndIf;
			
		Try
			If DeleteDirectly Then
				ProcessObjectWithMessagesTrapping(Object, "DirectDelete", Undefined, WriteParameters);
			Else
				ProcessObjectWithMessagesTrapping(Object, "DeletionMark", Undefined, WriteParameters);
			EndIf;
		Except
			ErrorInfo = ErrorInfo();
			AddReplacementResult(DeletionResult, Ref, 
				ReplacementErrorDescription("ErrorDelete", Ref, REFPRESENTATION,
				NStr("en='Removal failed';ru='Ошибка удаления'") + Chars.LF + TrimAll( BriefErrorDescription(ErrorInfo))));
		EndTry;
			
		If Not WriteParameters.PrivilegedRecord Then
			SetPrivilegedMode(True);
		EndIf;
	EndDo;
	
	If InternalTransaction Then
		CommitTransaction();
	EndIf;
EndProcedure

Procedure AddChangedObjectsReplacementResults(FinalTable, TableSearchAgain)
	
	TypeRecordKey = TypeDescriptionRecordsKeys();
	
	Filter = New Structure("ErrorType, Ref, ErrorObject", "");
	For Each String In TableSearchAgain Do
		Test = New Structure("AuxiliaryData", False);
		FillPropertyValues(Test, String);
		If Test.AuxiliaryData Then
			Continue;
		EndIf;
		
		Data = String.Data;
		Ref = String.Ref;
		
		DataPresentation = String(Data);
		
		Filter.ErrorObject = Data;
		Filter.Ref       = Ref;
		If FinalTable.FindRows(Filter).Count() = 0 Then
			AddReplacementResult(FinalTable, Ref, 
				ReplacementErrorDescription("DataChanged", Data, DataPresentation,
				NStr("en='Data was added or changed by another user';ru='Данные были добавлены или изменены другим пользователем'")));
		EndIf;
	EndDo;
	
EndProcedure

Function SetDimensionsDescription(Val Meta, Cache)
	
	DimensionsDescription = Cache[Meta];
	If DimensionsDescription<>Undefined Then
		Return DimensionsDescription;
	EndIf;
	
	// Period and registrar if any.
	DimensionsDescription = New Structure;
	
	DimensionData = New Structure("Master, Presentation, Format, Type", False);
	
	If Metadata.InformationRegisters.Contains(Meta) Then
		// There may be a period
		MetaPeriod = Meta.InformationRegisterPeriodicity; 
		Periodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity;
		
		If MetaPeriod = Periodicity.RecorderPosition Then
			DimensionData.Type           = Documents.AllRefsType();
			DimensionData.Presentation = NStr("en='Recorder';ru='Регистратор'");
			DimensionData.Master       = True;
			DimensionsDescription.Insert("Recorder", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Year Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en='Accounting period';ru='Отчетный период'");
			DimensionData.Format        = "L=en_EN; FD = yyyy y.; Am = Date is not set";
			DimensionsDescription.Insert("Period", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Day Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en='Accounting period';ru='Отчетный период'");
			DimensionData.Format        = "L=en_EN; DLF=D; Am = Date is not set";
			DimensionsDescription.Insert("Period", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Quarter Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en='Accounting period';ru='Отчетный период'");
			DimensionData.Format        =  "L=en_EN; FS = to ""quarter"" yyyy "" y. ; Am = Date is not set";
			DimensionsDescription.Insert("Period", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Month Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en='Accounting period';ru='Отчетный период'");
			DimensionData.Format        = "L=en_EN; FS=MMMM yyyy y.; Am = Date is not set";
			DimensionsDescription.Insert("Period", DimensionData);
			
		ElsIf MetaPeriod = Periodicity.Second Then
			DimensionData.Type           = New TypeDescription("Date");
			DimensionData.Presentation = NStr("en='Accounting period';ru='Отчетный период'");
			DimensionData.Format        = "L=en_EN; DLF=DT; Am = Date is not set";
			DimensionsDescription.Insert("Period", DimensionData);
			
		EndIf;
		
	Else
		DimensionData.Type           = Documents.AllRefsType();
		DimensionData.Presentation = NStr("en='Recorder';ru='Регистратор'");
		DimensionData.Master       = True;
		DimensionsDescription.Insert("Recorder", DimensionData);
		
	EndIf;
	
	// All dimensions
	For Each MetaDimension In Meta.Dimensions Do
		DimensionData = New Structure("Master, Presentation, Format, Type");
		DimensionData.Type           = MetaDimension.Type;
		DimensionData.Presentation = MetaDimension.Presentation();
		DimensionData.Master       = MetaDimension.Master;
		DimensionsDescription.Insert(MetaDimension.Name, DimensionData);
	EndDo;
	
	Cache[Meta] = DimensionsDescription;
	Return DimensionsDescription;
EndFunction

Function MovementsDescription(Val Meta)
	// can be cached by Meta
	
	MovementsDescription = New Array;
	If Not Metadata.Documents.Contains(Meta) Then
		Return MovementsDescription;
	EndIf;
	
	For Each RegisterRecord In Meta.RegisterRecords Do
		
		If Metadata.AccumulationRegisters.Contains(RegisterRecord) Then
			RecordSet = AccumulationRegisters[RegisterRecord.Name].CreateRecordSet();
			ExcludeFields = "Activity, LineNumber, Period, Registrar"; 
			
		ElsIf Metadata.InformationRegisters.Contains(RegisterRecord) Then
			RecordSet = InformationRegisters[RegisterRecord.Name].CreateRecordSet();
			ExcludeFields = "Activity, MovementKind, LineNumber, Period, Registrar"; 
			
		ElsIf Metadata.AccountingRegisters.Contains(RegisterRecord) Then
			RecordSet = AccountingRegisters[RegisterRecord.Name].CreateRecordSet();
			ExcludeFields = "Activity, MovementKind, LineNumber, Period, Registrar"; 
			
		ElsIf Metadata.CalculationRegisters.Contains(RegisterRecord) Then
			RecordSet = CalculationRegisters[RegisterRecord.Name].CreateRecordSet();
			ExcludeFields = "Active, BasePeriodEnd, BasePeriodBeginning, LineNumber,
			                |ValidityPeriod, ValidityPeriodEnd, ValidityPeriod, RegistrationPeriodBeginning, RegistrationPeriod,
			                |Registrar, Storno, ActualValidityPeriod";
		Else
			// Unknown type
			Continue;
		EndIf;
		
		// Fields of a reference type and dimension - candidates.
		Definition = FieldsListsByType(RecordSet, RegisterRecord.Dimensions, ExcludeFields);
		If Definition.FieldList.Count() = 0 Then
			// There is no need to process
			Continue;
		EndIf;
		
		Definition.Insert("RecordSet", RecordSet);
		Definition.Insert("SpaceLock", RegisterRecord.FullName() );
		
		MovementsDescription.Add(Definition);
	EndDo;	// Movements metadata
	
	Return MovementsDescription;
EndFunction

Function SequencesDescription(Val Meta)
	
	SequencesDescription = New Array;
	If Not Metadata.Documents.Contains(Meta) Then
		Return SequencesDescription;
	EndIf;
	
	For Each Sequence In Metadata.Sequences Do
		If Not Sequence.Documents.Contains(Meta) Then
			Continue;
		EndIf;
		
		TableName = Sequence.FullName();
		
		// List of fields and dimensions
		Definition = FieldsListsByType(TableName, Sequence.Dimensions, "Recorder");
		If Definition.FieldList.Count() > 0 Then
			
			Definition.Insert("RecordSet",           Sequences[Sequence.Name].CreateRecordSet());
			Definition.Insert("SpaceLock", TableName + ".Records");
			Definition.Insert("Dimensions",              New Structure);
			
			SequencesDescription.Add(Definition);
		EndIf;
		
	EndDo;
	
	Return SequencesDescription;
EndFunction

Function ObjectDescription(Val Meta)
	// can be cached by Meta
	
	AllRefsType = TypeDescriptionAllReferences();
	
	Candidates = New Structure("Attributes, StandardAttributes, TabularSections, StandardTabularSections");
	FillPropertyValues(Candidates, Meta);
	
	ObjectDescription = New Structure;
	
	ObjectDescription.Insert("Attributes", New Structure);
	If Candidates.Attributes <> Undefined Then
		For Each MetaAttribute In Candidates.Attributes Do
			If TypeDescriptionsIntersect(MetaAttribute.Type, AllRefsType) Then
				ObjectDescription.Attributes.Insert(MetaAttribute.Name);
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDescription.Insert("StandardAttributes", New Structure);
	If Candidates.StandardAttributes <> Undefined Then
		Excluded = New Structure("Ref");
		
		For Each MetaAttribute In Candidates.StandardAttributes Do
			Name = MetaAttribute.Name;
			If Not Excluded.Property(Name) AND TypeDescriptionsIntersect(MetaAttribute.Type, AllRefsType) Then
				ObjectDescription.Attributes.Insert(MetaAttribute.Name);
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDescription.Insert("TabularSections", New Array);
	If Candidates.TabularSections <> Undefined Then
		For Each MetaTable In Candidates.TabularSections Do
			
			FieldList = New Structure;
			For Each MetaAttribute In MetaTable.Attributes Do
				If TypeDescriptionsIntersect(MetaAttribute.Type, AllRefsType) Then
					FieldList.Insert(MetaAttribute.Name);
				EndIf;
			EndDo;
			
			If FieldList.Count() > 0 Then
				ObjectDescription.TabularSections.Add(New Structure("Name, FieldList", MetaTable.Name, FieldList));
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDescription.Insert("StandardTabularSections", New Array);
	If Candidates.StandardTabularSections <> Undefined Then
		For Each MetaTable In Candidates.StandardTabularSections Do
			
			FieldList = New Structure;
			For Each MetaAttribute In MetaTable.StandardAttributes Do
				If TypeDescriptionsIntersect(MetaAttribute.Type, AllRefsType) Then
					FieldList.Insert(MetaAttribute.Name);
				EndIf;
			EndDo;
			
			If FieldList.Count() > 0 Then
				ObjectDescription.StandardTabularSections.Add(New Structure("Name, FieldList", MetaTable.Name, FieldList));
			EndIf;
		EndDo;
	EndIf;
	
	ObjectDescription.Insert("CanBePosted", Metadata.Documents.Contains(Meta));
	Return ObjectDescription;
EndFunction

Function RecordKeyDescription(Val Meta)
	// can be cached by Meta
	
	TableName = Meta.FullName();
	
	// Fields of a reference type - candidates and dimensions set.
	KeyDescription = FieldsListsByType(TableName, Meta.Dimensions, "Period, Registrar");
		
	If Metadata.InformationRegisters.Contains(Meta) Then
		RecordSet = InformationRegisters[Meta.Name].CreateRecordSet();
		
	ElsIf Metadata.AccumulationRegisters.Contains(Meta) Then
		RecordSet = AccumulationRegisters[Meta.Name].CreateRecordSet();
		
	ElsIf Metadata.AccountingRegisters.Contains(Meta) Then
		RecordSet = AccountingRegisters[Meta.Name].CreateRecordSet();
		
	ElsIf Metadata.CalculationRegisters.Contains(Meta) Then
		RecordSet = CalculationRegisters[Meta.Name].CreateRecordSet();
		
	Else
		RecordSet = Undefined;
	EndIf;
		
	KeyDescription.Insert("RecordSet", RecordSet);
	KeyDescription.Insert("SpaceLock", TableName);

	Return KeyDescription;
EndFunction

Function LockListDescription(Val Block)
	// Unique values only
	Processed = New Map;
	
	DescriptionString = "";
	For Each Item In Block Do
		For Each Field In Item.Fields Do
			Value = Field.Value;
			If Processed[Value] = Undefined Then
				DescriptionString = DescriptionString + Chars.LF + Field.Value;
				Processed[Value] = True;
			EndIf
		EndDo;
	EndDo;
	
	Return TrimL(DescriptionString);
EndFunction

Function TypeDescriptionsIntersect(Val Description1, Val Description2)
	
	For Each Type In Description1.Types() Do
		If Description2.ContainsType(Type) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

// Returns the description by the table name or by the records set.
Function FieldsListsByType(Val DataSource , Val MetaDimensions, Val ExcludeFields)
	// can be cached
	
	Definition = New Structure;
	Definition.Insert("FieldList",     New Structure);
	Definition.Insert("DimensionList", New Structure);
	Definition.Insert("LeadingList",   New Structure);
	
	ControlType = TypeDescriptionAllReferences();
	Excluded = New Structure(ExcludeFields);
	
	DataSourceType = TypeOf(DataSource);
	
	If DataSourceType = Type("String") Then
		// Source - table name, receive fields using query.
		Query = New Query("SELECT * FROM " + DataSource + " WHERE FALSE");
		FieldsSource = Query.Execute();
	Else
		// Source - records set
		FieldsSource = DataSource.UnloadColumns();
	EndIf;
	
	For Each Column In FieldsSource.Columns Do
		Name = Column.Name;
		If Not Excluded.Property(Name) AND TypeDescriptionsIntersect(Column.ValueType, ControlType) Then
			Definition.FieldList.Insert(Name);
			
			// And check for the leading dimension.
			Meta = MetaDimensions.Find(Name);
			If Meta <> Undefined Then
				Definition.DimensionList.Insert(Name, Meta.Type);
				Test = New Structure("Master", False);
				FillPropertyValues(Test, Meta);
				If Test.Master Then
					Definition.LeadingList.Insert(Name, Meta.Type);
				EndIf;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Definition;
EndFunction

Procedure AddReplacementResult(Table, Val Ref, Val ErrorDescription)
	String = Table.Add();
	
	String.Ref = Ref;
	
	String.ErrorObjectPresentation = ErrorDescription.ErrorObjectPresentation;
	String.ErrorObject               = ErrorDescription.ErrorObject;
	String.ErrorText                = ErrorDescription.ErrorText;
	String.ErrorType                  = ErrorDescription.ErrorType;
	
EndProcedure

Function ReplacementErrorDescription(Val ErrorType, Val ErrorObject, Val ErrorObjectPresentation, Val ErrorText)
	Result = New Structure;
	
	Result.Insert("ErrorType",                  ErrorType);
	Result.Insert("ErrorObject",               ErrorObject);
	Result.Insert("ErrorObjectPresentation", ErrorObjectPresentation);
	Result.Insert("ErrorText",                ErrorText);
	
	Return Result;
EndFunction

Procedure ReplaceInStringsCollection(Collection, Val FieldList, Val SubstitutionsPairs)
	WorkingCollection = Collection.Unload();
	Modified = False;
	
	For Each String In WorkingCollection Do
		
		For Each KeyValue In FieldList Do
			Name = KeyValue.Key;
			TargetRef = SubstitutionsPairs[ String[Name] ];
			If TargetRef <> Undefined Then
				String[Name] = TargetRef;
				Modified = True;
			EndIf;
		EndDo;
		
	EndDo;
	
	If Modified Then
		Collection.Load(WorkingCollection);
	EndIf;
EndProcedure

Procedure TellPostponedMessages(Val Messages)
	
	For Each Message In Messages Do
		Message.Message();
	EndDo;
	
EndProcedure

Procedure ProcessObjectWithMessagesTrapping(Val Object, Val Action, Val WriteMode, Val WriteParameters)
	
	// Remember current messages up to exception.
	PreviousMessages = GetUserMessages(True);
	InformAgain    = CurrentRunMode() <> Undefined;
	
	Try
		
		If Action = "Record" Then
			SetParametersRecords(Object, WriteParameters);
			If WriteMode = Undefined Then
				Object.Write();
			Else
				Object.Write(WriteMode);
			EndIf;
			
		ElsIf Action = "DeletionMark" Then
			SetParametersRecords(Object, WriteParameters);
			Object.SetDeletionMark(True, False);
			
		ElsIf Action = "DirectDelete" Then
			SetParametersRecords(Object, WriteParameters);
			Object.Delete();
			
		EndIf;
		
	Except
		Information = ErrorInfo(); 
		
		// Catch everything that is reported when an error occurs and add it to one exception.
		ErrorMessage = "";
		For Each Message In GetUserMessages(False) Do
			ErrorMessage = ErrorMessage + Chars.LF + Message.Text;
		EndDo;
		
		// Inform  the previous
		If InformAgain Then
			TellPostponedMessages(PreviousMessages);
		EndIf;
		
		Raise TrimAll(BriefErrorDescription(Information) + Chars.LF + TrimAll(ErrorMessage));
	EndTry;
	
	If InformAgain Then
		TellPostponedMessages(PreviousMessages);
	EndIf;
	
EndProcedure

Procedure WriteObject(Val Object, Val WriteParameters)
	
	ObjectMetadata = Object.Metadata();
	
	If ThisIsDocument(ObjectMetadata) Then
		ProcessObjectWithMessagesTrapping(Object, "Record", DocumentWriteMode.Write, WriteParameters);
		Return;
	EndIf;
	
	// Check for possible cyclical refs.
	AttributesTest= New Structure("Hierarchical, ExtDimensionTypes, Owners", False, Undefined, New Array);
	FillPropertyValues(AttributesTest, ObjectMetadata);
	
	// By parent
	If AttributesTest.Hierarchical Or AttributesTest.ExtDimensionTypes <> Undefined Then 
		
		If Object.Parent = Object.Ref Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Circular reference occurs in hierarchy when writing %1.';ru='При записи %1 возникает циклическая ссылка в иерархии.'"),
				String(Object));
			EndIf;
			
	EndIf;
	
	// By owner
	For Each MetaOwner In AttributesTest.Owners Do
		
		If Object.Owner = Object.Ref Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Circular reference occurs in subordination when writing %1.';ru='При записи %1 возникает циклическая ссылка в подчинении.'"),
				String(Object));
		EndIf;
		Break;
		
	EndDo;
	
	// Just a record
	ProcessObjectWithMessagesTrapping(Object, "Record", Undefined, WriteParameters);
EndProcedure

Procedure SetParametersRecords(Object, Val WriteParameters)
	
	AttributesTest = New Structure("DataExchange");
	FillPropertyValues(AttributesTest, Object);
	If TypeOf(AttributesTest.DataExchange) = Type("DataExchangeParameters") Then
		Object.DataExchange.Load = WriteParameters.DoNotCheck;
		Object.DataExchange.Recipients.AutoFill = Not WriteParameters.DoNotCheck;
	EndIf;
	
	Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism", WriteParameters.DoNotCheck);
	
EndProcedure

Function EventLogMonitorEventRefsReplacements()
	Return NStr("en='Search and delete duplicates';ru='Поиск и удаление дубликатов'", 
		Metadata.DefaultLanguage.LanguageCode);
EndFunction

Procedure ReplaceRefsWithShortTransactions(ReplacementResult, Val ReplacementParameters, Val ExecutedReplacements, Val SearchTable)
	
	// Main processor cycle
	WriteParameters = New Structure;
	WriteParameters.Insert("DoNotCheck", Not ReplacementParameters.ControlOnWrite);
	WriteParameters.Insert("PrivilegedRecord", ReplacementParameters.PrivilegedRecord);
	
	RefsFilter = New Structure("Ref, ReplacementKey");
	For Each Ref In ExecutedReplacements Do
		RefsFilter.Ref = Ref;
		
		RefsFilter.ReplacementKey = "Constant";
		UsagePlaces = SearchTable.FindRows(RefsFilter);
		For Each UsagePlace In UsagePlaces Do
			ReplaceInConstant(ReplacementResult, UsagePlace, WriteParameters);
		EndDo;
		
		RefsFilter.ReplacementKey = "Object";
		UsagePlaces = SearchTable.FindRows(RefsFilter);
		For Each UsagePlace In UsagePlaces Do
			ReplaceInObject(ReplacementResult, UsagePlace, WriteParameters);
		EndDo;
		
		RefsFilter.ReplacementKey = "RecordKey";
		UsagePlaces = SearchTable.FindRows(RefsFilter);
		For Each UsagePlace In UsagePlaces Do
			ReplaceInSet(ReplacementResult, UsagePlace, WriteParameters);
		EndDo;
	EndDo;
	
	// Final actions
	If ReplacementParameters.DeleteDirectly Then
		DeleteRefsDirectly(ReplacementResult, ExecutedReplacements, WriteParameters, True);
		
	ElsIf ReplacementParameters.MarkToDelete Then
		DeleteRefsWithMarkup(ReplacementResult, ExecutedReplacements, WriteParameters);
		
	Else 
		// Search for new
		TableSearchAgain = UsagePlaces(ExecutedReplacements);
		AddChangedObjectsReplacementResults(ReplacementResult, TableSearchAgain);
	EndIf;
		
EndProcedure

Procedure ReplaceRefWithLongTransaction(ReplacementResult, Val Ref, Val ReplacementParameters, Val SearchTable)
	SetPrivilegedMode(True);
	
	WriteParameters = New Structure;
	WriteParameters.Insert("DoNotCheck", Not ReplacementParameters.ControlOnWrite);
	WriteParameters.Insert("PrivilegedRecord", ReplacementParameters.PrivilegedRecord);
	
	ActionState = "";
	
	// 1. Lock all places of use.
	Block = New DataLock;
	
	ConstantUsagePlaces = SearchTable.FindRows(New Structure("Ref, ReplacementKey", Ref, "Constant"));
	AddLockObjectsConstants(Block, ConstantUsagePlaces);
	
	UsagePlacesObjects = SearchTable.FindRows(New Structure("Ref, ReplacementKey", Ref, "Object"));
	AddLockObjectsObjects(Block, UsagePlacesObjects);
	
	UsagePlacesSets = SearchTable.FindRows(New Structure("Ref, ReplacementKey", Ref, "RecordKey"));
	AddLocksObjectsSets(Block, UsagePlacesSets);
		
	BeginTransaction();
	Try
		Block.Lock();
	Except
		// Add record about an unsuccessful attempt to lock the result.
		Error = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot lock all usage locations %1';ru='Не удалось заблокировать все места использования %1'"),
			Ref
		);
		AddReplacementResult(ReplacementResult, Ref, 
			ReplacementErrorDescription("LockError", Undefined, Undefined, Error)
		);
	
		ActionState = "LockError";
	EndTry;
	
	SetPrivilegedMode(False);
	
	// 2. Replacement is everywhere until the first error.
	If ActionState = "" Then
		ErrorsCount = ReplacementResult.Count();
		
		For Each UsagePlace In ConstantUsagePlaces Do
			ReplaceInConstant(ReplacementResult, UsagePlace, WriteParameters, False);
			If ErrorsCount <> ReplacementResult.Count() Then
				Break;
			EndIf;
		EndDo;
		
		If ErrorsCount = ReplacementResult.Count() Then
			For Each UsagePlace In UsagePlacesObjects Do
				ReplaceInObject(ReplacementResult, UsagePlace, WriteParameters, False);
				If ErrorsCount <> ReplacementResult.Count() Then
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If ErrorsCount = ReplacementResult.Count() Then
			For Each UsagePlace In UsagePlacesSets Do
				ReplaceInSet(ReplacementResult, UsagePlace, WriteParameters, False);
				If ErrorsCount <> ReplacementResult.Count() Then
					Break;
				EndIf;
			EndDo;
		Else
			ActionState = "RecordingError";
		EndIf;
		
	EndIf;
	
	// 3. Delete 
	ExecutedReplacements = New Array;
	ExecutedReplacements.Add(Ref);
	
	If ActionState = "" Then
		ErrorsCount = ReplacementResult.Count();
		
		If ReplacementParameters.DeleteDirectly Then
			DeleteRefsDirectly(ReplacementResult, ExecutedReplacements, WriteParameters, False);
			
		ElsIf ReplacementParameters.MarkToDelete Then
			DeleteRefsWithMarkup(ReplacementResult, ExecutedReplacements, WriteParameters, False);
			
		Else 
			// Search for new
			TableSearchAgain = UsagePlaces(ExecutedReplacements);
			AddChangedObjectsReplacementResults(ReplacementResult, TableSearchAgain);
		EndIf;
		
		If ErrorsCount <> ReplacementResult.Count() Then
			ActionState = "DataChanged";
		EndIf;
	EndIf;
	
	If ActionState = "" Then
		CommitTransaction();
	Else
		RollbackTransaction();
	EndIf;
	
EndProcedure
	
Procedure AddLockObjectsConstants(Block, Val UsageRows)
	
	For Each String In UsageRows Do
		Block.Add(String.Metadata.FullName());
	EndDo;
	
EndProcedure

Procedure AddLockObjectsObjects(Block, Val UsageRows)
	
	For Each UsagePlace In UsageRows Do
		Data = UsagePlace.Data;
		Meta   = UsagePlace.Metadata;
		
		// Item itself
		Block.Add(Meta.FullName()).SetValue("Ref", Data);
		
		// RegisterRecords 
		MovementsDescription = MovementsDescription(Meta);
		For Each Item In MovementsDescription Do
			// All by the registrar
			Block.Add(Item.SpaceLock + ".RecordSet").SetValue("Recorder", Data);
			
			// All candidates - dimensions for saving totals.
			For Each KeyValue In Item.DimensionList Do
				DimensionType  = KeyValue.Value;
				For Each UsagePlace In UsageRows Do
					CurrentRef = UsagePlace.Ref;
					If DimensionType.ContainsType(TypeOf(CurrentRef)) Then
						Block.Add(Item.SpaceLock).SetValue(KeyValue.Key, UsagePlace.Ref);
					EndIf;
				EndDo;
			EndDo;
		EndDo;
		
		// Sequences
		SequencesDescription = SequencesDescription(Meta);
		For Each Item In SequencesDescription Do
			Block.Add(Item.SpaceLock).SetValue("Recorder", Data);
			
			For Each KeyValue In Item.DimensionList Do
				DimensionType  = KeyValue.Value;
				For Each UsagePlace In UsageRows Do
					CurrentRef = UsagePlace.Ref;
					If DimensionType.ContainsType(TypeOf(CurrentRef)) Then
						Block.Add(Item.SpaceLock).SetValue(KeyValue.Key, CurrentRef);
					EndIf;
				EndDo;
			EndDo;
		EndDo;
	
	EndDo;

EndProcedure

Procedure AddLocksObjectsSets(Block, Val UsageRows)
	
	For Each UsagePlace In UsageRows Do
		Data = UsagePlace.Data;
		Meta   = UsagePlace.Metadata; 
		
		DescriptionOfSet = RecordKeyDescription(Meta);
		RecordSet = DescriptionOfSet.RecordSet;
		
		For Each KeyValue In DescriptionOfSet.DimensionList Do
			DimensionType = KeyValue.Value;
			Name          = KeyValue.Key;
			Value     = Data[Name];
			
			For Each String In UsageRows Do
				CurrentRef = String.Ref;
				If DimensionType.ContainsType(TypeOf(CurrentRef)) Then
					Block.Add(DescriptionOfSet.SpaceLock).SetValue(Name, CurrentRef);
				EndIf;
			EndDo;
			
			RecordSet.Filter[Name].Set(Value);
		EndDo;
		
	EndDo;
	
EndProcedure

Function EvaluateDataValueByPath(Val Data, Val DataPath)
	PartsWays = StrReplace(DataPath, ".", Chars.LF);
	PathPartsQuantity = StrLineCount(PartsWays);
	
	InterimResult = Data;
	
	For IndexOf = 1 To PathPartsQuantity Do
		AttributeName = StrGetLine(PartsWays, IndexOf);
		
		Test = New Structure(AttributeName, Undefined);
		FillPropertyValues(Test, InterimResult);
		If Test[AttributeName] = Undefined Then
			Test[AttributeName] = -1;
			FillPropertyValues(Test, InterimResult);
			If Test[AttributeName] = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='An error occurred while calculating %1 for object %2. Attribute %3 is not found';ru='Ошибка вычисления %1 для объекта %2. Реквизит %3 не найден'"),
					DataPath, Data, AttributeName 
				);
			EndIf;
		EndIf;
		
		Result = Test[AttributeName];
		If IndexOf = PathPartsQuantity Then
			Return Result;
			
		ElsIf Result = Undefined Then
			// Cannot read further
			Return Undefined;
			
		EndIf;
		
		InterimResult = Result;
	EndDo;
	
	Return Undefined;
EndFunction

#EndRegion
