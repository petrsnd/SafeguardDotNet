package com.oneidentity.safeguard.safeguardjava.restclient;

import com.oneidentity.safeguard.safeguardjava.IProgressCallback;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.List;
import java.util.Set;
import org.apache.hc.core5.function.Supplier;
import org.apache.hc.core5.http.Header;
import org.apache.hc.core5.http.HttpEntity;

public class ByteArrayEntity implements HttpEntity {

    private OutputStreamProgress outstream;
    private final IProgressCallback progressCallback;
    private final long totalBytes;
    private final org.apache.hc.core5.http.io.entity.ByteArrayEntity delegate;

    public ByteArrayEntity(byte[] b, IProgressCallback progressCallback) {
        this.delegate = new org.apache.hc.core5.http.io.entity.ByteArrayEntity(b, null);
        this.progressCallback = progressCallback;
        this.totalBytes = b.length;
    }

    @Override
    public boolean isRepeatable() {
        return delegate.isRepeatable();
    }

    @Override
    public long getContentLength() {
        return delegate.getContentLength();
    }

    @Override
    public String getContentType() {
        return delegate.getContentType();
    }

    @Override
    public String getContentEncoding() {
        return delegate.getContentEncoding();
    }

    @Override
    public InputStream getContent() throws IOException {
        return delegate.getContent();
    }

    @Override
    public void writeTo(OutputStream outstream) throws IOException {
        this.outstream = new OutputStreamProgress(outstream, this.progressCallback, totalBytes);
        delegate.writeTo(this.outstream);
    }

    @Override
    public boolean isStreaming() {
        return delegate.isStreaming();
    }

    @Override
    public boolean isChunked() {
        return delegate.isChunked();
    }

    @Override
    public Set<String> getTrailerNames() {
        return delegate.getTrailerNames();
    }

    @Override
    public Supplier<List<? extends Header>> getTrailers() {
        return delegate.getTrailers();
    }

    @Override
    public void close() throws IOException {
        delegate.close();
    }

    public int getProgress() {
        if (outstream == null) {
            return 0;
        }
        long contentLength = getContentLength();
        if (contentLength <= 0) {
            return 0;
        }
        long writtenLength = outstream.getWrittenLength();
        return (int) (100*writtenLength/contentLength);
    }
}
