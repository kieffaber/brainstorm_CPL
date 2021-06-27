# process_ERPimage
This process can be used to produce an "ERP image" and a corresponding matrix file in Brainstorm.  The function behaves similarly to the ERP image function in EEGlab
in which files (i.e., trials) are sorted using metadta values like reaction time.

### Creating the Metadata File:
In order to use this function, a metadata file is required.  This file must contain a set of comma separated values with a metadata label in the first row of the 
file and the values corresponding with each file in subsequent rows.  You can have any number of metadata labels, and columns do not have to be the same length.

If using Google Sheets, Excel, or other speadsheet software to create your metadata file, your spreadsheet might look something like this: 
ReactionTime | Age
------------ | -------------
790 | 22
845 | 34
1245 | 
.|
.|
.|

... which can be saved in .csv format for use with process_ERPimage.  The .csv file can also be created using a simple text editor.  For example:
ReactionTime, Age<br>
790 , 22<br>
845 , 34<br>
1245 , <br>
. , <br>
. , <br>
. , <br>

*Note that vertical ellipses indicate that you may have many more values in the ReactionTime column when sorting single trials by comparison with the Age column when sorting participant files.*

## Using the Process

![GitHub Logo](/images/logo.png)
Format: ![Alt Text](url)
