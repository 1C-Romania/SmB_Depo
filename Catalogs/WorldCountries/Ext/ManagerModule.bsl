#Region ServiceProgramInterface

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Determines country data by the countries list or by OKSM classifier.
//
// Parameters:
//    CountryCode    - String, Number - OKSM country code. If it is not specified, then search by code is not executed.
//    Description - String        - country name. If it is not specified, then search by name is not executed.
//
// Returns:
//    Structure - fields:
//          * Code                - String - found country attribute.
//          * Description       - String - found country attribute.
//          * DescriptionFull - String - found country attribute.
//          * CodeAlpha2          - String - found country attribute.
//          * CodeAlpha3          - String - found country attribute.
//          * Ref             - CatalogRef.WorldCountries - found country attribute.
//    Undefined - country is not found.
//
Function WorldCountriesData(Val CountryCode = Undefined, Val Description = Undefined) Export
	If CountryCode=Undefined AND Description=Undefined Then
		Return Undefined;
	EndIf;
	
	NormalizedCode = CodeOfCountryOfWorld(CountryCode);
	If CountryCode=Undefined Then
		SearchCondition = "TRUE";
		FilterClassifier = New Structure;
	Else
		SearchCondition = "Code=" + ControlQuotationMarksInString(NormalizedCode);
		FilterClassifier = New Structure("Code", NormalizedCode);
	EndIf;
	
	If Description<>Undefined Then
		SearchCondition = SearchCondition + " AND Description=" + ControlQuotationMarksInString(Description);
		FilterClassifier.Insert("Description", Description);
	EndIf;
	
	Result = New Structure("Ref, Code, Description, DescriptionFull, AlphaCode2, AlphaCode3");
	
	Query = New Query("
		|SELECT TOP 1
		|	Ref, Code, Description, DescriptionFull, AlphaCode2, AlphaCode3
		|FROM
		|	Catalog.WorldCountries
		|WHERE
		|	" + SearchCondition + "
		|ORDER
		|	BY Description
		|");
		
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		FillPropertyValues(Result, Selection);
		
	Else
		ClassifierData = ClassifierTable();
		RowsOfData = ClassifierData.FindRows(FilterClassifier);
		If RowsOfData.Count()=0 Then
			Result = Undefined
		Else
			FillPropertyValues(Result, RowsOfData[0]);
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Specifies country data by OKSM classifier.
//
// Parameters:
//    CountryCode - String, Number - OKSM country code.
//
// Returns:
//    Structure - fields:
//          * Code                - String - found country attribute.
//          * Description       - String - found country attribute.
//          * DescriptionFull - String - found country attribute.
//          * CodeAlpha2          - String - found country attribute.
//          * CodeAlpha3          - String - found country attribute.
//    Undefined - country is not found.
//
Function ClassifierDataOfWorldCountriesByCode(Val CountryCode) Export
	
	ClassifierData = ClassifierTable();
	DataRow = ClassifierData.Find(CodeOfCountryOfWorld(CountryCode), "Code");
	If DataRow=Undefined Then
		Result = Undefined;
	Else
		Result = New Structure("Code, Description, DescriptionFull, AlphaCode2, AlphaCode3");
		FillPropertyValues(Result, DataRow);
	EndIf;
	
	Return Result;
EndFunction

// Specifies country data by OKSM classifier.
//
// Parameters:
//    Description - String - country name.
//
// Returns:
//    Structure - fields:
//          * Code                - String - found country attribute.
//          * Description       - String - found country attribute.
//          * DescriptionFull - String - found country attribute.
//          * CodeAlpha2          - String - found country attribute.
//          * CodeAlpha3          - String - found country attribute.
//    Undefined - country is not found.
//
Function WorldCountriesClassifierDataByName(Val Description) Export
	ClassifierData = ClassifierTable();
	DataRow = ClassifierData.Find(Description, "Description");
	If DataRow=Undefined Then
		Result = Undefined;
	Else
		Result = New Structure("Code, Description, DescriptionFull, AlphaCode2, AlphaCode3");
		FillPropertyValues(Result, DataRow);
	EndIf;
	
	Return Result;
EndFunction

// Updates world countries catalog by the layout data - classifier.
// Items that exist in the catalog are identified by the Code field.
//
// Parameters:
//    Add - Boolean - if True, then countries are added that are
//                         present in the classifier but are not present in the world countries catalog.
//
Procedure RefreshWorldCountriesByClassifier(Val Add = False) Export
	AllErrors = "";
	
	Filter = New Structure("Code");
	
	// You can not compare in the query because database may be independent from registration.
	For Each ClassifierRow IN ClassifierTable() Do
		Filter.Code = ClassifierRow.Code;
		Selection = Catalogs.WorldCountries.Select(,,Filter);
		CountryFound = Selection.Next();
		If Not CountryFound AND Add Then
			// Add country
			Country = Catalogs.WorldCountries.CreateItem();
		ElsIf CountryFound AND (
			      Selection.Description <> ClassifierRow.Description
			  Or Selection.AlphaCode2 <> ClassifierRow.AlphaCode2
			  Or Selection.AlphaCode3 <> ClassifierRow.AlphaCode3
			  Or Selection.DescriptionFull <> ClassifierRow.DescriptionFull
			) Then
			// Change country
			Country = Selection.GetObject();
		Else
			Continue;
		EndIf;
		
		BeginTransaction();
		Try
			If Not Country.IsNew() Then
				LockDataForEdit(Country.Ref);
			EndIf;
			FillPropertyValues(Country, ClassifierRow, "Code, Description, AlphaCode2, AlphaCode3, DescriptionFull");		
			Country.AdditionalProperties.Insert("DontCheckUniqueness");
			Country.Write();
			CommitTransaction();
		Except
			Info = ErrorInfo();
			ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Error of recording of the country of the world %1 (code% 2) when updating the classifier, 3%';ru='Ошибка записи страны мира %1 (код %2) при обновлении классификатора, %3'"),
				Selection.Code, Selection.Description, BriefErrorDescription(Info));
			WriteLogEvent(InfobaseUpdate.EventLogMonitorEvent(), 
				EventLogLevel.Error,,,
				ErrorText + Chars.LF + DetailErrorDescription(Info));
			AllErrors = AllErrors + Chars.LF + ErrorText;
			RollbackTransaction();
		EndTry;
		
	EndDo;
	
	If Not IsBlankString(AllErrors) Then
		Raise TrimAll(AllErrors);
	EndIf;
EndProcedure

// Creates or returns existing reference by the classifier data.
//
// Parameters:
//    Filter - Structure - contains field:
//          * Code - String - for search country in classifier.
//    Data - Structure - to fill in eponymous remaining fields of created object.
//
// Returns:
//     CatalogRef.WorldCountries - ref on created item.
//
Function ReferenceAccordingToClassifier(Val Filter, Val AdditionalInformation = Undefined) Export
	
	// Make sure that country is present in the classifier.
	DataSearch = ClassifierDataOfWorldCountriesByCode(Filter.Code);
	If DataSearch=Undefined Then
		Raise NStr("en='Invalid code of the country of the world for the search in the classifier';ru='Некорректный код страны мира для поиска в классификаторе'");
	EndIf;
	
	// Check whether it exists in catalog by the classifier data.
	DataSearch = WorldCountriesData(DataSearch.Code, DataSearch.Description);
	Result = DataSearch.Ref;
	If Not ValueIsFilled(Result) Then
		ObjectOfCountry = Catalogs.WorldCountries.CreateItem();
		FillPropertyValues(ObjectOfCountry, DataSearch);
		If AdditionalInformation<>Undefined Then
			FillPropertyValues(ObjectOfCountry, AdditionalInformation);
		EndIf;
		ObjectOfCountry.Write();
		Result = ObjectOfCountry.Ref;
	EndIf;
	
	Return Result;
EndFunction

#EndIf

// Returns check box of possibility to add and change items.
//
Function IsRightToAdd() Export
	
	Return AccessRight("Insert", Metadata.Catalogs.WorldCountries);
	
EndFunction

// Returns search fields in order of preference for world countries.
//
// Returns:
//    Array - contains structures with fields:
//      * Name                 - String - search attribute name.
//      * TemplatePresentation - String - template for generating presentation value by attribute
// names, for example: "%1.Name (%1.Code)". Here "Name" and "Code" - attributes
//                                       names,
//                                       "%1" - placeholder for passing table alias.
//
Function SearchFields() Export
	Result = New Array;
	FieldList = Catalogs.WorldCountries.EmptyRef().Metadata().InputByString;
	BoundaryFields = FieldList.Count() - 1;
	AllNamesByString = "";
	
	SeparatorPresentation = ", ";
	SplitterPresentation = " + """ + SeparatorPresentation + """ + ";
	
	For IndexOf=0 To BoundaryFields Do
		FieldName = FieldList[IndexOf].Name;
		AllNamesByString = AllNamesByString + "," + FieldName;
		
		PresentationPattern = "%1." + FieldName;
		
		OtherFields = "";
		For Position=0 To BoundaryFields Do
			If Position<>IndexOf Then
				OtherFields = OtherFields + SplitterPresentation + FieldList[Position].Name;
			EndIf;
		EndDo;
		If Not IsBlankString(OtherFields) Then
			PresentationPattern = PresentationPattern
				+ " + "" ("" + " 
				+ "%1." + Mid(OtherFields, StrLen(SplitterPresentation) + 1) 
				+ " + "")""";
		EndIf;
		
		Result.Add(
			New Structure("Name, PresentationPattern", FieldName, PresentationPattern)
		);
	EndDo;
	
	Return New Structure("FieldList, FieldNamesAsString", Result, Mid(AllNamesByString, 2));
EndFunction

// Returns full data of OKSM classifier.
//
// Returns:
//     ValueTable - classifier data with columns:
//         * Code                - String - country data.
//         * Description       - String - country data.
//         * DescriptionFull - String - country data.
//         * CodeAlpha2          - String - country data.
//         * CodeAlpha3          - String - country data.
//
//     Values table is indexed by the "Code", "Name" fields.
//
Function ClassifierTable() Export
	Template = Catalogs.WorldCountries.GetTemplate("Classifier");
	
	Read = New XMLReader;
	Read.SetString(Template.GetText());
	
	Return XDTOSerializer.ReadXML(Read);
EndFunction

#EndRegion

#Region EventsHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	If Not StandardProcessing Then 
		// Processed in another place.
		Return;
		
	ElsIf Not Parameters.Property("AllowClassifierData") Then
		// Default behavior, pick only catalog.
		Return;
		
	ElsIf True<>Parameters.AllowClassifierData Then
		// Classifier pick is disabled, default behavior.
		Return;
		
	ElsIf Not IsRightToAdd() Then
		// You have no rights to add world country, default behavior.
		Return;
		
	EndIf;
	
	// Imitate platform behavior - search by all available search fields and generate detailed list.
	
	// Imply that the fields of catalog and classifier match except for
	// the "Ref" field absent in the classifier.
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	FilterParameterPrefix = "FilterParameters";
	
	// Common filter by parameters
	SelectionTemplate = "TRUE";
	For Each KeyValue IN Parameters.Filter Do
		FieldValue = KeyValue.Value;
		FieldName      = KeyValue.Key;
		ParameterName = FilterParameterPrefix + FieldName;
		
		If TypeOf(FieldValue)=Type("Array") Then
			SelectionTemplate = SelectionTemplate + " AND %1." + FieldName + " IN (&" + ParameterName + ")";
		Else
			SelectionTemplate = SelectionTemplate + " AND %1." + FieldName + " = &" + ParameterName;
		EndIf;
		
		Query.SetParameter(ParameterName, KeyValue.Value);
	EndDo;
	
	// Additional filters
	If Parameters.Property("ChoiceFoldersAndItems") Then
		If Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
			SelectionTemplate = SelectionTemplate + " AND %1.IsFolder";
			
		ElsIf Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Items Then
			SelectionTemplate = SelectionTemplate + " AND (NOT %1.IsFolder)";
			
		EndIf;
	EndIf;
	
	// Data source
	If (Parameters.Property("OnlyClassifierData") AND Parameters.OnlyClassifierData) Then
		// Query only by classifier.
		QueryPattern = "
			|SELECT TOP 50
			|	NULL                       AS Ref,
			|	Classifier.Code          AS Code,
			|	Classifier.Description AS Description,
			|	FALSE                       AS DeletionMark,
			|	%2                         AS Presentation
			|FROM
			|	Classifier AS Classifier
			|WHERE
			|	Classifier.%1 LIKE &SearchString
			|	AND (
			|		" + StringFunctionsClientServer.PlaceParametersIntoString(SelectionTemplate, "Classifier") + "
			|	)
			|ORDER BY
			|Classifier.%1
			|";
	Else
		// Query both by catalog, and by classifier.
		QueryPattern = "
			|SELECT TOP 50 
			|	WorldCountries.Ref                                             AS Ref,
			|	ISNULL(WorldCountries.Code, Classifier.Code)                   AS Code,
			|	ISNULL(WorldCountries.Description, Classifier.Description) AS Description,
			|	ISNULL(WorldCountries.DeletionMark, FALSE)                    AS DeletionMark,
			|
			|	CASE WHEN WorldCountries.Ref IS NULL THEN 
			|		%2 
			|	ELSE 
			|		%3
			|	END AS Presentation
			|
			|FROM
			|	Catalog.WorldCountries AS WorldCountries
			|Full JOIN
			|	Classifier
			|ON
			|	Classifier.Code = WorldCountries.Code
			|	AND Classifier.Description = WorldCountries.Description
			|WHERE 
			|	(WorldCountries.%1 LIKE &SearchString OR Classifier.%1 LIKE &SearchString)
			|	AND (" + StringFunctionsClientServer.PlaceParametersIntoString(SelectionTemplate, "Classifier") + ") AND (" + StringFunctionsClientServer.PlaceParametersIntoString(SelectionTemplate, "WorldCountries") + ") ORDER BY ISNULL(WorldCountries.%1, Classifier.%1)
			|";
	EndIf;
	
	NamesOfFields = SearchFields();
	
	// Code + Description - key fields of match catalog to classifier. Always process them.
	FieldNamesByString = "," + StrReplace(NamesOfFields.FieldNamesAsString, " ", "");
	FieldNamesByString = StrReplace(FieldNamesByString, ",Code", "");
	FieldNamesByString = StrReplace(FieldNamesByString, ",Description", "");
	
	Query.Text = "
		|SELECT
		|	Code, Description " + FieldNamesByString + "
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Classifier
		|INDEX BY
		|	Code, Description
		|	" + FieldNamesByString + "
		|";
	Query.SetParameter("Classifier", ClassifierTable());
	Query.Execute();
	Query.SetParameter("SearchString", EncloseSimilarityChars(Parameters.SearchString) + "%");
	
	For Each FieldData IN NamesOfFields.FieldList Do
		Query.Text = StringFunctionsClientServer.PlaceParametersIntoString(QueryPattern, 
			FieldData.Name,
			StringFunctionsClientServer.PlaceParametersIntoString(FieldData.PresentationPattern, "Classifier"),
			StringFunctionsClientServer.PlaceParametersIntoString(FieldData.PresentationPattern, "WorldCountries"),
		);
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			ChoiceData = New ValueList;
			StandardProcessing = False;
			
			Selection = Result.Select();
			While Selection.Next() Do
				If ValueIsFilled(Selection.Ref) Then
					// Catalog data
					ChoiceItem = Selection.Ref;
				Else
					// Classifier data
					ChoiceResult = New Structure("Code, description", 
						Selection.Code, Selection.Description
					);
					
					ChoiceItem = New Structure("Value, DeletionMark, Warning",
						ChoiceResult, Selection.DeletionMark, Undefined,
					);
				EndIf;
				
				ChoiceData.Add(ChoiceItem, Selection.Presentation);
			EndDo;
		
			Break;
		EndIf;
	EndDo;
	
EndProcedure

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// Data import from the file

// Prohibits to import data to this catalog
// from subsystem "DataLoadFromFile" because this catalog implements its method of data import from template.
//
Function UseDataLoadFromFile() Export
	Return False;
EndFunction


#EndIf

#EndRegion

#Region ServiceProceduresAndFunctions

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Reduces country code to one kind - String with three characters length.
//
Function CodeOfCountryOfWorld(Val CountryCode)
	
	If TypeOf(CountryCode)=Type("Number") Then
		Return Format(CountryCode, "ND=3; NZ=; NLZ=; NG=");
	EndIf;
	
	Return Right("000" + CountryCode, 3);
EndFunction

// Returns quoted string.
//
Function ControlQuotationMarksInString(Val String)
	Return """" + StrReplace(String, """", """""") + """";
EndFunction

#EndIf

// Shields characters for use in the DETAILS query function.
//
Function EncloseSimilarityChars(Val Text, Val ESCAPE = "\")
	Result = Text;
	SimilarityChars = "%_[]^" + ESCAPE;
	
	For Position=1 To StrLen(SimilarityChars) Do
		CurrentChar = Mid(SimilarityChars, Position, 1);
		Result = StrReplace(Result, CurrentChar, ESCAPE + CurrentChar);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
