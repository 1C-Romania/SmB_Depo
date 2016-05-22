#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefDevelopmentOfNonCurrentAssets, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefDevelopmentOfNonCurrentAssets);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.Quantity AS Quantity
	|FROM
	|	Document.FixedAssetsOutput.FixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetsOutput", QueryResult.Unload());
	
EndProcedure // DocumentDataInitialization()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf