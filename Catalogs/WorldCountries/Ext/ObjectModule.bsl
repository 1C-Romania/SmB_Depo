#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

//  Controls the item uniqueness in the base.
//
//  Returns:
//      Undefined - no errors.
//      Structure - item description existing in the base. Properties:
//          * ErrorDescription     - String - error text.
//          * Code                 - String - attribute of the item that already exists.
//          * Description          - String - attribute of the item that already exists.
//          * DescriptionFull      - String - attribute of the item that already exists.
//          * CodeAlpha2           - String - attribute of the item that already exists.
//          * CodeAlpha3           - String - attribute of the item that already exists.
//          * Ref                  - CatalogRef.WorldCountries - attribute of the item that already exists.
//
Function ExistingItem() Export
	
	Result = Undefined;
	
	// Skip non-numeric codes
	NumberType = New TypeDescription("Number", New NumberQualifiers(3, 0, AllowedSign.Nonnegative));
	If Code="0" Or Code="00" Or Code="000" Then
		SearchingCode = "000";
	Else
		SearchingCode = Format(NumberType.AdjustValue(Code), "ND=3; NFD=2; NZ=; NLZ=");
		If SearchingCode="000" Then
			Return Result; // Not number
		EndIf;
	EndIf;
		
	Query = New Query("
		|SELECT TOP 1
		|	Code              AS Code,
		|	Description       AS Description,
		|	DescriptionFull   AS DescriptionFull,
		|	AlphaCode2        AS AlphaCode2,
		|	AlphaCode3        AS AlphaCode3,
		|	Ref               AS Ref
		|FROM
		|	Catalog.WorldCountries
		|WHERE
		|	Code=&Code 
		|	AND Ref <> &Ref
		|");
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Code",    SearchingCode);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		Result = New Structure("ErrorDescription", StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='The country %2 with code %1 already exists. Change the code or use the already existing data.';ru='С кодом %1 уже существует страна %2. Измените код или используйте уже существующие данные.'"), 
			Code, Selection.Description));
		
		For Each Field IN QueryResult.Columns Do
			Result.Insert(Field.Name, Selection[Field.Name]);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	If DataExchange.Load Or ThisObject.AdditionalProperties.Property("DontCheckUniqueness") Then
		Return;
	EndIf;
	
	If Not CheckFilling() Then
		Cancel = True;
	EndIf;
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	Existing = ExistingItem();
	If Existing<>Undefined Then
		Cancel = True;
		CommonUseClientServer.MessageToUser(Existing.ErrorDescription,, "Object.Description");
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	If FillingData<>Undefined Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
EndProcedure

#EndRegion

#EndIf
