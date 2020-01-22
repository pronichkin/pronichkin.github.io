Class
Cat
{
    [System.String]
    $Name

    Cat () {}

    Cat (
        $Name
    )
    {
        $this.Name = $Name
    }

    [System.String]
    Speak ()
    {
        Return "'Meow!,' said $($this.Name)"
    }
}