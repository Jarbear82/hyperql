import io.github.treesitter.jtreesitter.Language;
import io.github.treesitter.jtreesitter.hyperql.TreeSitterHyperql;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

public class TreeSitterHyperqlTest {
    @Test
    public void testCanLoadLanguage() {
        assertDoesNotThrow(() -> new Language(TreeSitterHyperql.language()));
    }
}
