
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DataFileAttached = GetDataFileAttachedPackageAtServer(CommandParameter);
	
	If Not DataFileAttached.PackageStatus = PredefinedValue("Enum.EDPackagesStatuses.Unknown")
		AND DataFileAttached.EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEDFOperatorTaxcom")
		AND ValueIsFilled(DataFileAttached.EDFrom)
		AND Not Find(DataFileAttached.EDFrom, "2AL") > 0 Then
		
		Return;
	EndIf;
	
	FileData = ElectronicDocumentsServiceCallServer.GetFileData(DataFileAttached.AttachedFile,
		CommandExecuteParameters.Source.UUID);
		
	GetFile(FileData.FileBinaryDataRef, FileData.FileName);
	
EndProcedure

&AtServer
Function GetDataFileAttachedPackageAtServer(EDPackage)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDAttachedFiles.Ref,
	|	EDAttachedFiles.FileOwner.EDExchangeMethod AS EDExchangeMethod,
	|	EDAttachedFiles.FileOwner.Sender AS Sender,
	|	EDAttachedFiles.FileOwner.PackageStatus AS PackageStatus
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", EDPackage);
	
	QueryResult = Query.Execute().Select();
	QueryResult.Next();
	
	DataStructurePackage = New Structure;
	DataStructurePackage.Insert("AttachedFile", QueryResult.Ref);
	DataStructurePackage.Insert("EDFrom",      QueryResult.Sender);
	DataStructurePackage.Insert("PackageStatus",       QueryResult.PackageStatus);
	DataStructurePackage.Insert("EDExchangeMethod",     QueryResult.EDExchangeMethod);
	
	Return DataStructurePackage;
	
EndFunction
