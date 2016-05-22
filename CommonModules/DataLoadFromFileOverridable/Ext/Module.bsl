////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data import from file".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Defines the list of catalogs available for import with the use of subsystem "Data import from file".
//
// Parameters:
//  Handlers - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      Author presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	ImportedCatalogs.Clear();
	
	Information = ImportedCatalogs.Add();
	Information.FullName = Metadata.Catalogs.ProductsAndServices.Name;
	Information.Presentation = Metadata.Catalogs.ProductsAndServices.Presentation();
	Information.AppliedImport = True;
	
	Information = ImportedCatalogs.Add();
	Information.FullName = Metadata.Catalogs.Counterparties.Name;
	Information.Presentation = Metadata.Catalogs.Counterparties.Presentation();
	Information.AppliedImport = True;
	
EndProcedure

#EndRegion
