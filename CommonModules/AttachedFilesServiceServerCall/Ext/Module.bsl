////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// See this procedure in the AttachedFiles module.
Procedure UpdateAttachedFile(Val AttachedFile, Val InformationAboutFile) Export
	
	AttachedFiles.UpdateAttachedFile(AttachedFile, InformationAboutFile);
	
EndProcedure

// See this function in the AttachedFiles module.
Function AddFile(Val FileOwner,
                     Val BaseName,
                     Val ExtensionWithoutDot = Undefined,
                     Val ModifiedAt = Undefined,
                     Val ModificationTimeUniversal = Undefined,
                     Val FileAddressInTemporaryStorage,
                     Val TextTemporaryStorageAddress = "",
                     Val Definition = "") Export
	
	Return AttachedFiles.AddFile(
		FileOwner,
		BaseName,
		ExtensionWithoutDot,
		ModifiedAt,
		ModificationTimeUniversal,
		FileAddressInTemporaryStorage,
		TextTemporaryStorageAddress,
		Definition);
	
EndFunction

// See this function in the AttachedFiles module.
Function GetFileData(Val AttachedFile,
                            Val FormID = Undefined,
                            Val GetRefToBinaryData = True,
                            Val ForEditing = False) Export
	
	Return AttachedFiles.GetFileData(
		AttachedFile, FormID, GetRefToBinaryData, ForEditing);
	
EndFunction

// See this procedure in the AttachedFilesService module.
Procedure Encrypt(Val AttachedFile, Val EncryptedData, Val ThumbprintArray) Export
	
	AttachedFilesService.Encrypt(
		AttachedFile, EncryptedData, ThumbprintArray);
	
EndProcedure

// See this procedure in the AttachedFilesService module.
Procedure Decrypt(Val AttachedFile, Val DecryptedData) Export
	
	AttachedFilesService.Decrypt(AttachedFile, DecryptedData);
	
EndProcedure

// See this procedure in the AttachedFiles module.
Procedure OverrideReceivedFormAttachedFile(Source,
                                                      FormKind,
                                                      Parameters,
                                                      SelectedForm,
                                                      AdditionalInformation,
                                                      StandardProcessing) Export
	
	AttachedFiles.OverrideReceivedFormAttachedFile(Source,
		FormKind,
		Parameters,
		SelectedForm,
		AdditionalInformation,
		StandardProcessing);
		
EndProcedure

#EndRegion
