////////////////////////////////////////////////////////////////////////////////
// Subsystem "Objects prefixation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Event handler during changing the number of the object.
// The handler is intended to find out the object's basic number
// in case when it is not possible to get the basic number by standard method without the loss of information.
// The handler is called only for the case when the
// processed numbers and objects codes were formed by non-standard method, and not in the format of numbers and SSL codes.
//
// Parameters:
//  Object - DocumentObject, BusinessProcessObject, TaskObject - Data
//           object for which it is necessary to define a basic number.
//  Number - String - Number of the current object from which it is necessary to extract a basic number.
//  BasicNumber - String - Basic number of the object. 
//           Under the basic number of the
//           object it is meant the object number excluding
//           all prefixes (IB prefix, company prefix, unit prefix, user prefix, etc.).
//  StandardProcessing - Boolean - Flag of the standard data processor. Default value is True.
//           If this parameter is set to False in the handler,
//           then the standard data processor will not be executed.
//           Standard data processor gets the basic code from the right to the first non-numeric character.
//           For example, for the code "AA00005/12/368" the standard processor will return "368".
//           However, the basic code for the object will be equal to "5/12/368".
//
Procedure OnNumberChange(Object, Val Number, BasicNumber, StandardProcessing) Export
	
	
	
EndProcedure

// Event handler when changing the object code.
// The handler is intended to find out the object's basic code 
// in case when it is not possible to get the basic code by standard method without the loss of information.
// The handler is called only for the case when the
// processed numbers and objects codes were formed by non-standard method, and not in the format of numbers and SSL codes.
//
// Parameters:
//  Object - CatalogObject, ChartOfCharacteristicTypesObject - Data
//           object for which it is necessary to define a basic code.
//  Code   - String - Code of the current object from which it is necessary to extract a basic code.
//  BasicCode - String - Basic code of the object. Under the basic code of the
//           object it is meant the object code excluding
//           all prefixes (IB prefix, company prefix, unit prefix, user prefix, etc.).
//  StandardProcessing - Boolean - Flag of the standard data processor. Default value is True.
//           If this parameter is set to False in the handler,
//           then the standard data processor will not be executed.
//           Standard data processor gets the basic code from the right to the first non-numeric character.
//           For example, for the code "AA00005/12/368" the standard processor will return "368".
//           However, the basic code for the object will be equal to "5/12/368".
//
Procedure OnCodeChange(Object, Val Code, BasicCode, StandardProcessing) Export
	
EndProcedure

// IN the procedure it is necessary to fill the
// Objects parameter for those metadata objects for which the ref to the company is located in the attribute with a name which is different from the standard name "Company".
//
// Parameters:
//  Objects - ValuesTable.
//     * Object    - MetadataObject - Metadata object for which an
//                   attribute is specified that contains a reference to the company.
//     * Attribute - String - Name of the attribute that contains a reference to the company.
//
Procedure GetPrefixesGeneratingAttributes(Objects) Export
	
	
	
EndProcedure

#EndRegion
