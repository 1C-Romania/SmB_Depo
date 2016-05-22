////////////////////////////////////////////////////////////////////////////////
// Subsystem "Objects prefixation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Returns trait of changing organization or object date.
// 
// Parameters:
//  Refs - reference to the IB object.
//  DateAfterChange - object date after change.
//  CounterpartyAfterChange - object organization after chamge.
// 
//  Returns:
//   True - object organization was changes or a
//            new object date was specified on another periodicity interval in comparison with the previous date value.
//   False - organization and object date were not changed.
//
Function DateOrCompanyOfObjectChanged(Refs, Val DateAfterChange, Val CounterpartyAfterChange, FullTableName) Export
	
	QueryText = "
	|SELECT
	|	ObjectHeader.Date                                AS Date,
	|	ISNULL(ObjectHeader.[AttributeNameCompany].Prefix, """") AS CompanyPrefixBeforeChange
	|FROM
	|	" + FullTableName + " AS
	|ObjectHeader
	|WHERE ObjectHeader.Link = & Link
	|";
	
	QueryText = StrReplace(QueryText, "[AttributeNameOrganization]", ObjectPrefixationEvents.AttributeNameCompany(FullTableName));
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Refs);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	CompanyPrefixAfterChange = Undefined;
	ObjectsReprefixation.WhenPrefixDefinitionOrganization(CounterpartyAfterChange, CompanyPrefixAfterChange);
	
	// If a null reference to the organization is set.
	CompanyPrefixAfterChange = ?(CompanyPrefixAfterChange = False, "", CompanyPrefixAfterChange);
	
	Return Selection.CompanyPrefixBeforeChange <> CompanyPrefixAfterChange
		OR Not OnePeriodObjectDates(Selection.Date, DateAfterChange, Refs);
	//
EndFunction

// Returns trait of changing object organization.
//
// Parameters:
//  Refs - reference to the IB object.
//  CounterpartyAfterChange - object organization after chamge.
//
//  Returns:
//   True - object organization was changed. False - organization was not changed.
//
Function CompanyOfObjectChanged(Refs, Val CounterpartyAfterChange, FullTableName) Export
	
	QueryText = "
	|SELECT
	|	ISNULL(ObjectHeader.[AttributeNameCompany].Prefix, """") AS CompanyPrefixBeforeChange
	|FROM
	|	" + FullTableName + " AS
	|ObjectHeader
	|WHERE ObjectHeader.Link = & Link
	|";
	
	QueryText = StrReplace(QueryText, "[AttributeNameOrganization]", ObjectPrefixationEvents.AttributeNameCompany(FullTableName));
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Refs);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	CompanyPrefixAfterChange = Undefined;
	ObjectsReprefixation.WhenPrefixDefinitionOrganization(CounterpartyAfterChange, CompanyPrefixAfterChange);
	
	// If a null reference to the organization is set.
	CompanyPrefixAfterChange = ?(CompanyPrefixAfterChange = False, "", CompanyPrefixAfterChange);
	
	Return Selection.CompanyPrefixBeforeChange <> CompanyPrefixAfterChange;
	
EndFunction

// Defines trait of equality of two dates for a metadata object.
// Dates are equal if they are from the same time period: Year, Month, Day etc.
// 
// Parameters:
// Date1 - first date for comparison;
// Date2 - second date for comparison.;
// ObjectMetadata - metadata of the object , for which you need to get the value of function.
// 
//  Returns:
//   True - object date of one period; False - object dates of different periods.
//
Function OnePeriodObjectDates(Val Date1, Val Date2, Refs) Export
	
	ObjectMetadata = Refs.Metadata();
	
	If DocumentNumberPeriodicityYear(ObjectMetadata) Then
		
		DATEDIFF = BegOfYear(Date1) - BegOfYear(Date2);
		
	ElsIf DocumentNumberPeriodicityQuarter(ObjectMetadata) Then
		
		DATEDIFF = BegOfQuarter(Date1) - BegOfQuarter(Date2);
		
	ElsIf DocumentNumberPeriodicityMonth(ObjectMetadata) Then
		
		DATEDIFF = BegOfMonth(Date1) - BegOfMonth(Date2);
		
	ElsIf DocumentNumberPeriodicityDay(ObjectMetadata) Then
		
		DATEDIFF = BegOfDay(Date1) - BegOfDay(Date2);
		
	Else // DocumentNumberPeriodicityUndefined
		
		DATEDIFF = 0;
		
	EndIf;
	
	Return DATEDIFF = 0;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

Function DocumentNumberPeriodicityYear(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year;
	
EndFunction

Function DocumentNumberPeriodicityQuarter(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter;
	
EndFunction

Function DocumentNumberPeriodicityMonth(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month;
	
EndFunction

Function DocumentNumberPeriodicityDay(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day;
	
EndFunction

#EndRegion
