
#Region SB

Procedure GenerateDataChecksPresentation(Form) Export
	
	ComponentsFS = New Array;
	
	If Not IsBlankString(Form.DuplicateChecksPresentation) Then
		ComponentsFS.Add(Form.DuplicateChecksPresentation);
		ComponentsFS.Add(Chars.LF);
	EndIf;
	
	If ComponentsFS.Count() > 0 Then
		ComponentsFS.Delete(ComponentsFS.UBound());
	EndIf;
	
	Form.DataChecksPresentation = New FormattedString(ComponentsFS);
	Form.Items.DataChecksPresentation.Visible = Not IsBlankString(Form.DataChecksPresentation);
	If Not IsBlankString(Form.DataChecksPresentation) Then
		Form.Items.DataChecksPresentation.Height = StrLineCount(Form.DataChecksPresentation);
	EndIf;
	
EndProcedure

#EndRegion