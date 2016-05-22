////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns a maximum file size.
//
// Returns:
//  Number - byte integer.
//
Function MaximumFileSize() Export
	
	SetPrivilegedMode(True);
	
	MaximumFileSize = Constants.MaximumFileSize.Get();
	
	If MaximumFileSize = Undefined
	 OR MaximumFileSize = 0 Then
		
		MaximumFileSize = 50*1024*1024; // 50 mb
		Constants.MaximumFileSize.Set(MaximumFileSize);
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND CommonUseReUse.CanUseSeparatedData() Then
		
		MaxDataAreaFileSize =
			Constants.MaxDataAreaFileSize.Get();
		
		If MaxDataAreaFileSize = Undefined
		 OR MaxDataAreaFileSize = 0 Then
			
			MaxDataAreaFileSize = 50*1024*1024; // 50 mb
			
			Constants.MaxDataAreaFileSize.Set(
				MaxDataAreaFileSize);
		EndIf;
		
		MaximumFileSize = min(MaximumFileSize, MaxDataAreaFileSize);
	EndIf;
	
	Return MaximumFileSize;
	
EndFunction

// Returns the provider's maximum file size.
//
// Returns:
//  Number - byte integer.
//
Function MaximumFileSizeCommon() Export
	
	SetPrivilegedMode(True);
	
	MaximumFileSize = Constants.MaximumFileSize.Get();
	
	If MaximumFileSize = Undefined
	 OR MaximumFileSize = 0 Then
		
		MaximumFileSize = 50*1024*1024; // 50 mb
		Constants.MaximumFileSize.Set(MaximumFileSize);
	EndIf;
	
	Return MaximumFileSize;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operations with file volumes

// Whether at least one file storage volume exists.
//
// Returns:
//  Boolean - If True, then at least one working volume exists.
//
Function AreFileStorageVolumes() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion
