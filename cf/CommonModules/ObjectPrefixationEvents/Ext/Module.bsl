////////////////////////////////////////////////////////////////////////////////
// Subsystem "Objects prefixation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Sets the prefix of the subscription source in compliance with the company prefix. 
// Subscription source must contain required attribute
// of the header "Company" with CatalogRef type.Companies".
//
// Parameters:
//  Source - The source of the subscription event.
//           Any object from the set [Catalog, Document, Chart of characteristic kinds, Business process, Task].
// StandardProcessing - Boolean - flag of the subscription standard data processor.
// Prefix - String - object prefix that should be changed.
//
Procedure SetCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, False, True);
	
EndProcedure

// Sets the prefix of the subscription source in compliance with the infobase prefix.
// It does not impose restrictions on the source attributes.
//
// Parameters:
//  Source - The source of the subscription event.
//           Any object from the set [Catalog, Document, Chart of characteristic kinds, Business process, Task].
// StandardProcessing - Boolean - flag of the subscription standard data processor.
// Prefix - String - object prefix that should be changed.
//
Procedure SetIBPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, False);
	
EndProcedure

// Sets the prefix of the subscription source in compliance with the infobase prefix and company prefix.
// Subscription source must contain required attribute
// of the header "Company" with CatalogRef type.Companies".
//
// Parameters:
//  Source - The source of the subscription event.
//           Any object from the set [Catalog, Document, Chart of characteristic kinds, Business process, Task].
// StandardProcessing - Boolean - flag of the subscription standard data processor.
// Prefix - String - object prefix that should be changed.
//
Procedure SetIBAndCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For catalogs

// Checks the modified status of the Company attribute of the catalog item.
// If the Company attribute is changed, then the Item code will be reset to zero.
// It is required to assign a new code to the item.
//
// Parameters:
//  Source - CatalogObject - the source of the subscription event.
//  Cancel - Boolean - Failure flag.
// 
Procedure CheckCatalogCodeByCompany(Source, Cancel) Export
	
	CheckObjectCodeByCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For business processes

// Checks the modified status of the business process date.
// If date is not included in the previous period, then the number of the business process is reset to zero.
// It is required to assign a new number to the business process number.
//
// Parameters:
//  Source - BusinessProcessObject - the source of the subscription event.
//  Cancel - Boolean - Failure flag.
// 
Procedure CheckBusinessProcessNumberByDate(Source, Cancel) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks the modified status of the date and company of the business process.
// If the date is not included in the previous period or the Company attribute is changed, then the business process number is reset to zero.
// It is required to assign a new number to the business process number.
//
// Parameters:
//  Source - BusinessProcessObject - the source of the subscription event.
//  Cancel - Boolean - Failure flag.
// 
Procedure CheckBusinessProcessNumberByDateAndCompany(Source, Cancel) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For documents

// Checks the modified status of the document date.
// If the date is not included in the previous period, then the document number is reset to zero.
// It is required to assign a new number to the document.
//
// Parameters:
//  Source - DocumentObject - the source of the subscription event.
//  Cancel - Boolean - Failure flag.
// 
Procedure CheckDocumentNumberByDate(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks the modified status of the date and company of the document.
// If the date is not included in the previous period or the Company attribute is changed, then the document number is reset to zero.
// It is required to assign a new number to the document.
//
// Parameters:
//  Source - DocumentObject - the source of the subscription event.
//  Cancel - Boolean - Failure flag.
// 
Procedure CheckDocumentNumberByDateAndCompany(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SetPrefix(Source, Prefix, SetIBPrefix, SetCompanyPrefix)
	
	InfobasePrefix = "";
	CompanyPrefix        = "";
	
	If SetIBPrefix Then
		
		ObjectsReprefixation.WhenDeterminingPrefixInformationBase(InfobasePrefix);
		
		SupplementStringWithZerosOnTheLeft(InfobasePrefix, 2);
	EndIf;
	
	If SetCompanyPrefix Then
		
		If AttributeCompanyIsAvailable(Source) Then
			
			ObjectsReprefixation.WhenPrefixDefinitionOrganization(
				Source[AttributeNameCompany(Source.Metadata())], CompanyPrefix);
			// If a null reference to the organization is set.
			If CompanyPrefix = False Then
				
				CompanyPrefix = "";
				
			EndIf;
			
		EndIf;
		
		SupplementStringWithZerosOnTheLeft(CompanyPrefix, 2);
	EndIf;
	
	PrefixTemplate = "[OR][Infobase]-[Prefix]";
	PrefixTemplate = StrReplace(PrefixTemplate, "[OR]", CompanyPrefix);
	PrefixTemplate = StrReplace(PrefixTemplate, "[Infobase]", InfobasePrefix);
	PrefixTemplate = StrReplace(PrefixTemplate, "[Prefix]", Prefix);
	
	Prefix = PrefixTemplate;
	
EndProcedure

Procedure SupplementStringWithZerosOnTheLeft(String, StringLength)
	
	String = StringFunctionsClientServer.SupplementString(String, StringLength, "0", "Left");
	
EndProcedure

Procedure CheckObjectNumberByDate(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	EndIf;
	
	ObjectMetadata = Object.Metadata();
	
	QueryText = "
	|SELECT
	|	ObjectHeader.Date AS Date
	|FROM
	|	" + ObjectMetadata.FullName() + " AS
	|ObjectHeader
	|WHERE ObjectHeader.Link = & Link
	|";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	If Not ObjectPrefixationService.OnePeriodObjectDates(Selection.Date, Object.Date, Object.Ref) Then
		Object.Number = "";
	EndIf;
	
EndProcedure

Procedure CheckObjectNumberByDateAndCompany(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	EndIf;
	
	If ObjectPrefixationService.DateOrCompanyOfObjectChanged(Object.Ref, Object.Date,
		Object[AttributeNameCompany(Object.Metadata())], Object.Metadata().FullName()) Then
		
		Object.Number = "";
		
	EndIf;
	
EndProcedure

Procedure CheckObjectCodeByCompany(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	ElsIf Not AttributeCompanyIsAvailable(Object) Then
		Return;
	EndIf;
	
	If ObjectPrefixationService.CompanyOfObjectChanged(Object.Ref,	
		Object[AttributeNameCompany(Object.Metadata())], Object.Metadata().FullName()) Then
		
		Object.Code = "";
		
	EndIf;
	
EndProcedure

Function AttributeCompanyIsAvailable(Object)
	
	// Return value of the function.
	Result = True;
	
	ObjectMetadata = Object.Metadata();
	
	If   (CommonUse.ThisIsCatalog(ObjectMetadata)
		OR CommonUse.ThisIsChartOfCharacteristicTypes(ObjectMetadata))
		AND ObjectMetadata.Hierarchical Then
		
		AttributeNameCompany = AttributeNameCompany(ObjectMetadata);
		
		AttributeCompany = ObjectMetadata.Attributes.Find(AttributeNameCompany);
		
		If AttributeCompany = Undefined Then
			
			If CommonUse.ThisIsStandardAttribute(ObjectMetadata.StandardAttributes, AttributeNameCompany) Then
				
				// Standard attribute is always available for the item and for the group.
				Return True;
				
			EndIf;
			
			MessageString = NStr("en='Attribute with the ""%2"" name is not defined for metadata object %1.';ru='Для объекта метаданных %1 не определен реквизит с именем %2.'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ObjectMetadata.FullName(), AttributeNameCompany);
			Raise MessageString;
		EndIf;
			
		If AttributeCompany.Use = Metadata.ObjectProperties.AttributeUse.ForFolder AND Not Object.IsFolder Then
			
			Result = False;
			
		ElsIf AttributeCompany.Use = Metadata.ObjectProperties.AttributeUse.ForItem AND Object.IsFolder Then
			
			Result = False;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// For an internal use.
Function AttributeNameCompany(Object) Export
	
	If TypeOf(Object) = Type("MetadataObject") Then
		DescriptionFull = Object.FullName();
	Else
		DescriptionFull = Object;
	EndIf;
	
	Attribute = ObjectPrefixationReUse.PrefixesGeneratingAttributes().Get(DescriptionFull);
	
	If Attribute <> Undefined Then
		Return Attribute;
	EndIf;
	
	Return "Company";
	
EndFunction

#EndRegion
