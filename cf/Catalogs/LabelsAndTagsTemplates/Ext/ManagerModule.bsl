#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function gets the field name from the available fields of data composition.
//
Function GetFieldNameInTemplate(Val FieldName) Export
	
	FieldName = StrReplace(FieldName, ".DeletionMark", ".DeletionMark");
	FieldName = StrReplace(FieldName, ".Owner", ".Owner");
	FieldName = StrReplace(FieldName, ".Code", ".Code");
	FieldName = StrReplace(FieldName, ".Parent", ".Parent");
	FieldName = StrReplace(FieldName, ".Predefined", ".Predefined");
	FieldName = StrReplace(FieldName, ".IsFolder", ".IsFolder");
	FieldName = StrReplace(FieldName, ".Description", ".Description");
	Return FieldName;
	
EndFunction // GetFieldNameInTemplate()

#EndRegion

#EndIf