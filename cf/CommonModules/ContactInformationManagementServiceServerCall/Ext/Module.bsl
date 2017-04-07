﻿////////////////////////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// It parses presentation of the contact information and returns an XML string with the field values.
//
//  Parameters:
//      Text        - String - XML
//      ExpectedType - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes - to
//                     control types.
//
//  Returns:
//      String - XML
//
Function PresentationXMLContactInformation(Val Text, Val ExpectedKind) Export
	Return ContactInformationManagement.PresentationXMLContactInformation(Text, ExpectedKind);
EndFunction

//  Returns enumeration value type of the contact information kind.
//
//  Parameters:
//      InformationKind - CatalogRef.ContactInformationTypes, Structure - source data.
//
//  Returns:
//      EnumRefContactInfomationTypes - value of the Type field.
//
Function TypeKindContactInformation(Val InformationKind) Export
	
	Return ContactInformationManagementService.TypeKindContactInformation(InformationKind);
	
EndFunction

// It returns the list of string identifiers available for copying to the current addresses.
// 
Function AddressesAvailableForCopying(Val FieldsForAnalysisValues, Val AddressKind) Export
	
	Return ContactInformationManagementService.AddressesAvailableForCopying(FieldsForAnalysisValues, AddressKind);
	
EndFunction

// It returns the found reference or creates new world country and returns a reference to it.
//
Function WorldCountryAccordingToClassifier(Val CountryCode) Export
	
	Return Catalogs.WorldCountries.RefByClassifier(
		New Structure("Code", CountryCode));
		
EndFunction

// It fills the collection with the links to the found or created world countries.
//
Procedure CollectionOfWorldCountriesAccordingToClassifier(Collection) Export
	
	For Each KeyValue In Collection Do
		Collection[KeyValue.Key] = Catalogs.WorldCountries.RefByClassifier(
			New Structure("Code", KeyValue.Value.Code));
	EndDo;
		
EndProcedure

#EndRegion
