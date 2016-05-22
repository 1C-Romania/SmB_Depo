////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillTableFilesOfPackageED()
	
	ProcessedPackages.Clear();
	
	PackagesQuery = New Query;
	RemovableStatusesPackages = New ValueList;
	RemovableStatusesPackages.Add(Enums.EDPackagesStatuses.Canceled);
	RemovableStatusesPackages.Add(Enums.EDPackagesStatuses.Delivered);
	RemovableStatusesPackages.Add(Enums.EDPackagesStatuses.Unpacked);
	PackagesQuery.SetParameter("PackageStatus", RemovableStatusesPackages);
	
	PackagesQuery.Text =
	"SELECT DISTINCT ALLOWED
	|	EDAttachedFiles.Ref AS Document,
	|	EDAttachedFiles.FileOwner.PackageStatus AS Status,
	|	FALSE AS Selected,
	|	EDAttachedFiles.CreationDate AS DateReceived,
	|	EDAttachedFiles.FileOwner.Company AS Company,
	|	EDAttachedFiles.FileOwner.Counterparty AS Counterparty,
	|	EDAttachedFiles.FileOwner.Direction AS Direction
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner REFS Document.EDPackage
	|	AND EDAttachedFiles.DeletionMark = FALSE
	|	AND CAST(EDAttachedFiles.FileOwner AS Document.EDPackage).PackageStatus IN (&PackageStatus)";
	
	ValueToFormAttribute(PackagesQuery.Execute().Unload(), "ProcessedPackages");
	
EndProcedure

&AtServer
Procedure DeleteData()
	
	For Each RemovalLine IN ProcessedPackages Do
		If RemovalLine.Selected Then
			RemovalObject = RemovalLine.Document.GetObject();
			RemovalObject.DeletionMark = True;
			RemovalObject.Write();
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetCheckBoxes(InstallationOption)
	
	For Each String IN ProcessedPackages Do
		String.Selected = InstallationOption;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure UncheckAll(Command)
	
	SetCheckBoxes(False);
	
EndProcedure

&AtClient
Procedure SelectAll(Command)
	
	SetCheckBoxes(True);
	
EndProcedure

&AtClient
Procedure MarkToDeleteMarkedPED(Command)
	
	DeleteData();
	RefreshDataTables(Undefined);
	
EndProcedure

&AtClient
Procedure RefreshDataTables(Command)
	
	FillTableFilesOfPackageED();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure ProcessedPackagesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ElectronicDocumentsServiceClient.OpenEDForViewing(Items.ProcessedPackages.CurrentData.Document);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillTableFilesOfPackageED();
	
EndProcedure
