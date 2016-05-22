#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns a list of attributes which can be edited with the use of the batch modification processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	EditableAttributes.Add("Comment");
	
	Return EditableAttributes;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
Procedure AddQueriesToUseExternalResourcesAllVolumes(Queries) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileStorageVolumes.Ref AS Ref,
	|	FileStorageVolumes.FullPathLinux,
	|	FileStorageVolumes.FullPathWindows,
	|	FileStorageVolumes.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Queries.Add(QueryOnExternalResourcesUseForVolume(
			Selection.Ref, Selection.FullPathWindows, Selection.FullPathLinux));
	EndDo;
	
EndProcedure

// Only for internal use.
Procedure AddQueriesToAbolitionUseExternalResourcesAllVolumes(Queries) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileStorageVolumes.Ref AS Ref,
	|	FileStorageVolumes.FullPathLinux,
	|	FileStorageVolumes.FullPathWindows,
	|	FileStorageVolumes.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Queries.Add(WorkInSafeMode.QueryOnClearPermissionToUseExternalResources(
			Selection.Ref));
	EndDo;
	
EndProcedure

// Only for internal use.
Function QueryOnExternalResourcesUseForVolume(Volume, FullPathWindows, FullPathLinux) Export
	
	permissions = New Array;
	
	If ValueIsFilled(FullPathWindows) Then
		permissions.Add(WorkInSafeMode.PermissionToUseFileSystemDirectory(
			FullPathWindows, True, True));
	EndIf;
	
	If ValueIsFilled(FullPathLinux) Then
		permissions.Add(WorkInSafeMode.PermissionToUseFileSystemDirectory(
			FullPathLinux, True, True));
	EndIf;
	
	Return WorkInSafeMode.QueryOnExternalResourcesUse(permissions, Volume);
	
EndFunction

#EndRegion

#EndIf
