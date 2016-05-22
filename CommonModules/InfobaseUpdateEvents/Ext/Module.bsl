////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB version update".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Procedures used during the data exchange.

// This procedure is the event handler WhenSendingDataToSubordinate.
//
// Parameters:
// see description of the OnSendDataToSubordinate event handler in the syntax helper.
// 
Procedure OnSubsystemsVersionsSending(DataItem, ItemSend, Val CreatingInitialImage = False) Export
	
	If ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// Do not override standard data processor.
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.SubsystemVersions") Then
		
		If CreatingInitialImage Then
			
			If CommonUseReUse.DataSeparationEnabled() Then
				
				If CommonUseReUse.CanUseSeparatedData() Then
					
					For Each SetRow IN DataItem Do
						
						QueryText =
						"SELECT
						|	DataAreasSubsystemVersions.Version AS Version
						|FROM
						|	InformationRegister.DataAreasSubsystemVersions AS DataAreasSubsystemVersions
						|WHERE
						|	DataAreasSubsystemVersions.SubsystemName = &SubsystemName";
						
						Query = New Query;
						Query.SetParameter("SubsystemName", SetRow.SubsystemName);
						Query.Text = QueryText;
						
						Selection = Query.Execute().Select();
						
						If Selection.Next() Then
							
							SetRow.Version = Selection.Version;
							
						Else
							
							SetRow.Version = "";
							
						EndIf;
						
					EndDo;
					
				EndIf;
				
			Else
				
				// When you create initial image with
				// disabled division, export the register without additional data processor.
				
			EndIf;
			
		Else
			
			// Export the register only when you create initial image.
			ItemSend = DataItemSend.Ignore;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
