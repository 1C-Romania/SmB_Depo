////////////////////////////////////////////////////////////////////////////////
// Subsystem "Information center".
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// Returns a table with info references for forms
//
// Parameters:
// HashPathToForm - String - hash of a full path to the form.
//
// Returns:
// ValueTable - table of info references for a form with columns:
// 	Description - String - name of info ref
// 	Address - String - external address of info ref
// 	Weight - Number - info ref weight 
// 	ActualityBeginningDate - Date - Start date of the information reference relevance
// 	ActualityEndingDate - Date - End date of the information reference relevance
// 	ToolTip - String - information reference tooltip
//
Function GetTableInformationLinksForForms(HashPathToForm) Export
	
	Query = New Query;
	Query.SetParameter("Hash", HashPathToForm);
	Query.SetParameter("CurrentDate", CurrentDate());
	Query.Text = 
	"SELECT
	|	FullPathsToForms.Ref AS Ref
	|INTO PathToForms
	|FROM
	|	Catalog.FullPathsToForms AS FullPathsToForms
	|WHERE
	|	FullPathsToForms.Hash = &Hash
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InformationReferencesForForms.Description AS Description,
	|	InformationReferencesForForms.Address AS Address,
	|	InformationReferencesForForms.Weight AS Weight,
	|	InformationReferencesForForms.ActualityBeginningDate AS ActualityBeginningDate,
	|	InformationReferencesForForms.ActualityEndingDate AS ActualityEndingDate,
	|	InformationReferencesForForms.ToolTip AS ToolTip
	|FROM
	|	PathToForms AS PathToForms
	|		INNER JOIN Catalog.InformationReferencesForForms AS InformationReferencesForForms
	|		ON PathToForms.Ref = InformationReferencesForForms.FullPathToForm
	|WHERE
	|	InformationReferencesForForms.ActualityBeginningDate <= &CurrentDate
	|	AND InformationReferencesForForms.ActualityEndingDate >= &CurrentDate
	|
	|ORDER BY
	|	Weight DESC";
	
	Return Query.Execute().Unload();
	
EndFunction
