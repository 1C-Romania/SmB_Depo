////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Subsystem "Address classifier".
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Identifies the name with the abbreviation of the state by its code.
//
// Parameters:
//    RFTerritorialEntityCode - Number, String - state code.
//
// Returns:
//    String       - state name and abbreviation. 
//    Undefined - If the State is not found.
//
Function StateNameByCode(RFTerritorialEntityCode) Export
	
	Query = New Query("
		|SELECT TOP 1
		|	Description + "" "" + Abbr AS Description
		|FROM
		|	InformationRegister.AddressObjects
		|WHERE
		|	Level = 1
		|	AND RFTerritorialEntityCode = &RFTerritorialEntityCode
		|");
		
	NumberType = New TypeDescription("Number");
	NumericEntityCode = NumberType.AdjustValue(RFTerritorialEntityCode);
		
	Query.SetParameter("RFTerritorialEntityCode", NumericEntityCode );
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		Return Selection.Description;
	EndIf;
	
	// If it is not found, then search also the classifier - template.
	Classifier = InformationRegisters.AddressObjects.RFTerritorialEntitiesClassifier();
	Variant = Classifier.Find(RFTerritorialEntityCode, "RFTerritorialEntityCode");
	If Variant = Undefined Then
		// It was not found
		Return Undefined;
	EndIf;
	
	Return Variant.Description + " " + Variant.Abbr;
EndFunction

// Returns a state code by its name.
//
// Parameters:
//    Description - String - name or full name (with abbreviation) of the state.
//
// Returns:
//    Number        - state code.
//    Undefined - if data is not found.
//
Function StateCodeByName(Description) Export
	
	Query = New Query("
		|SELECT 
		|	Variants.RFTerritorialEntityCode
		|FROM (
		|	SELECT TOP 1
		|		1             AS Order,
		|		RFTerritorialEntityCode AS RFTerritorialEntityCode
		|	FROM
		|		InformationRegister.AddressObjects
		|	WHERE
		|		Level = 1 
		|		AND Description = &Description
		|
		|	UNION ALL
		|
		|	SELECT TOP 1
		|		2             AS Order,
		|		RFTerritorialEntityCode AS RFTerritorialEntityCode
		|	FROM
		|		InformationRegister.AddressObjects
		|	WHERE
		|		Level = 1 
		|		AND Description = &Description
		|		AND Abbr   = &Abbr
		|) AS Variants
		|
		|ORDER BY
		|	Variants.Order
		|");
		
	WordParts = AddressClassifierClientServer.DescriptionAndAbbreviation(Description);
	Query.SetParameter("Description", WordParts.Description);
	Query.SetParameter("Abbr",   WordParts.Abbr);
	Query.SetParameter("Description",     Description);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		Return Selection.RFTerritorialEntityCode;
	EndIf;

	// If it is not found, then search also the classifier - template.
	Classifier = InformationRegisters.AddressObjects.RFTerritorialEntitiesClassifier();
	
	Filter = New Structure("Description", Description);
	Variants = Classifier.FindRows(Filter);
	If Variants.Count() = 0 Then
		Filter.Insert("Description", WordParts.Description);
		Filter.Insert("Abbr",   WordParts.Abbr);
		Variants = Classifier.FindRows(Filter);
	EndIf;
	
	If Variants.Count() > 0 Then
		Return Variants[0].RFTerritorialEntityCode;
	EndIf;
	
	Return Undefined;
EndFunction

// Returns information for all known territorial entities of the Russian Federation (both classifier and loaded ones).
//
// Returns:
//     ValueTable - supplied data. Contains columns:
//       * RFTerritorialEntityCode  - Number  - territorial entity classifier code, for example, 77 for Moscow.
//       * Description   - String - Entity name by the classifier. For example, "Moscow".
//       * Abbreviation     - String - Entity name by the classifier. ForExample "prov".
//       * PostalCode - Number  - state index. If 0 - than index is not defined.
//       * Identifier  - UUID - FIAS identifier.
//
Function RFTerritorialEntitiesClassifier() Export
	
	Return InformationRegisters.AddressObjects.RFTerritorialEntitiesClassifier();
	
EndFunction

// Determines the quantity of territorial entities of the Russian Federation by which address classifier is loaded.
//
// Returns:
//    Number - number of states with loaded data.
//
Function ImportedStatesQuantity() Export
	
	If AddressClassifierService.AddressClassifierDataSourceWebService() Then
		Return RFTerritorialEntitiesClassifier().Count();
	EndIf;
	
	Query = New Query("
		|SELECT
		|	COUNT(States.RFTerritorialEntityCode) AS ImportedQuantity
		|FROM
		|	InformationRegister.AddressObjects AS States
		|WHERE
		|	States.Level = 1
		|	AND 1 In (
		|		SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|		WHERE Level = 2 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|		WHERE Level = 3 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|		WHERE Level = 4 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|		WHERE Level = 5 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|		WHERE Level = 6 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|		WHERE Level = 7 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|		WHERE Level = 90 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|		UNION ALL SELECT TOP 1 1 FROM InformationRegister.AddressObjects
		|		WHERE Level = 91 AND RFTerritorialEntityCode = States.RFTerritorialEntityCode
		|	)
		|");
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.ImportedQuantity;
	EndIf;
	
	Return 0;
EndFunction

// Address classifier workload check.
//
// Returns:
//     Boolean - True if the address classifier is imported for at least one state, False - otherwise.
//
Function ClassifierImported() Export
	
	If AddressClassifierService.AddressClassifierDataSourceWebService() Then
		Return True;
	EndIf;
	
	Query = New Query("
		|SELECT TOP 1
		|	RFTerritorialEntityCode
		|FROM
		|	InformationRegister.AddressObjects
		|WHERE
		|	Level > 1
		|");
	
	Return Not Query.Execute().IsEmpty();
EndFunction

// Checks addresses for matching the classifier.
//
// Parameters:
//     Addresses - Array - checked addresses. Contains structures with fields:
//         * Address                             - XDTOObject, Row - Checked
//                                               address ((http://www.v8.1c.ru/ssl/contactinfo) RFAddress) or
//                                               its XML-serialization.
//         * AddressFormat - String - Type of used for check by classifier. If "CLADR" then
//                                   check is performed only by CLADR levels.
//
// Returns:
//     Array - analysis results. Each item of array contains structures with fields:
//       *Errors   - Array     - Errors of search in classifier description. Consists of structures with fields.
//           ** Key     - String  - Service identifier of an error location - XPath path in XDTO object.
//           ** Text    - String  - Error text.
//           ** Promting - String - Text of a possible change of an error.
//       * Variants - Array     - Contains description of the found variants. Each item - structure with fields.
//           ** Identifier    - UUID  - object classifier identifier - variant.
//           ** Index           - Number - Postal code of the object - variant.
//           ** CLADRCode         - Number - CLADR code of the nearest object.
//           ** OKATO            - Number - FTS data.
//           ** OKTMO            - Number - FTS data.
//           ** CodeIFTSIndividual        - Number - FTS data.
//           ** CodeIFTSLegEnt        - Number - FTS data.
//           ** DepartmentCodeIFTSIndividual - Number - FTS data.
//           ** DepartmentCodeIFTSLegalEntity - Number - FTS data.
//
Function ValidateAddresses(Addresses) Export
	
	Result = AddressClassifierService.AddressesCheckResultByClassifier(Addresses);
	Return Result.Data;
	
EndFunction

// Returns full name of an address object by its abbreviation.
// If no level is specified then it returns the first match found
//
// Parameters:
//  AddressAbbreviation	 - String - breaking of
//  the address object Level				 - Number - Code the address object level
//
// Returns:
//  String - full name of
//  an address object Undefined - if the abbr is not found.
//
Function FullDescrAddressAbbreviation(AddressAbbreviation, Level = Undefined) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1 
		|	AddressInformationReductionsLevels.Value AS Description
		|FROM
		|	InformationRegister.AddressInformationReductionsLevels AS AddressInformationReductionsLevels
		|WHERE
		|	AddressInformationReductionsLevels.Abbr = &Abbr";
	
	If ValueIsFilled(Level) Then 
		Query.Text = Query.Text + " AND AddressInformationReductionsLevels.Level = &Level";
		Query.SetParameter("Level", Level);
	EndIf;
	Query.SetParameter("Abbr", AddressAbbreviation);
	
	QueryResult = Query.Execute().Select();;
	
	While QueryResult.Next() Do
		Return QueryResult.Description;
	EndDo;
	
	Return Undefined;
	
EndFunction

// Outdated. You should use ImportedStatesQuantity or ClassifierImported.
//
Function NumberOfFilledAddressObjects() Export
	
	Return ImportedStatesQuantity();
	
EndFunction

#EndRegion

